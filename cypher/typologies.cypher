// =====================================================================
// AML Graph - Cypher typology detection queries
// Data: IBM Transactions for Anti-Money Laundering (HI-Small), loaded as
//       (:Account)-[:SENT {n_txns, total_amount, laundering}]->(:Account)
// Each query detects a known money-laundering typology and is validated
// against HI-Small_Patterns.txt.
// =====================================================================

// ---------------------------------------------------------------------
// LOAD (run once)
// ---------------------------------------------------------------------
// CREATE CONSTRAINT account_id IF NOT EXISTS
// FOR (a:Account) REQUIRE a.id IS UNIQUE;
//
// LOAD CSV WITH HEADERS FROM 'file:///graph_nodes.csv' AS row
// CALL (row) {
//   CREATE (:Account {id: row.account, laundering: toInteger(row.laundering_involved)})
// } IN TRANSACTIONS OF 10000 ROWS;
//
// LOAD CSV WITH HEADERS FROM 'file:///graph_edges.csv' AS row
// CALL (row) {
//   MATCH (f:Account {id: row.FromAccount})
//   MATCH (t:Account {id: row.ToAccount})
//   CREATE (f)-[:SENT {n_txns: toInteger(row.n_txns),
//                      total_amount: toFloat(row.total_amount),
//                      laundering: toInteger(row.any_laundering)}]->(t)
// } IN TRANSACTIONS OF 10000 ROWS;

// ---------------------------------------------------------------------
// TYPOLOGY 1 - FAN-OUT (smurfing: one account sprays money to many)
// Note: raw out-degree surfaces big legitimate hubs (banks). Filtering
// on the fraction of laundering isolates the deliberate smurfing hubs.
// Validated: top hit is account 800737690 = the 16-degree fan-out in
// HI-Small_Patterns.txt.
// ---------------------------------------------------------------------
MATCH (sender:Account)-[r:SENT]->(receiver:Account)
WITH sender,
     count(DISTINCT receiver) AS receivers,
     sum(r.laundering) AS laundering_edges
WHERE receivers >= 8 AND laundering_edges >= 5
RETURN sender.id AS account, receivers, laundering_edges,
       round(100.0 * laundering_edges / receivers, 1) AS pct_laundering
ORDER BY pct_laundering DESC, laundering_edges DESC
LIMIT 15;

// Visualize one fan-out ring (for screenshots)
MATCH p=(s:Account {id: '800737690'})-[:SENT]->(r:Account)
RETURN p;

// ---------------------------------------------------------------------
// TYPOLOGY 2 - FAN-IN (consolidation: many accounts funnel into one)
// Mirror of fan-out: group by receiver, count distinct senders.
// ---------------------------------------------------------------------
MATCH (sender:Account)-[r:SENT]->(receiver:Account)
WITH receiver,
     count(DISTINCT sender) AS senders,
     sum(r.laundering) AS laundering_edges
WHERE senders >= 8 AND laundering_edges >= 5
RETURN receiver.id AS account, senders, laundering_edges,
       round(100.0 * laundering_edges / senders, 1) AS pct_laundering
ORDER BY pct_laundering DESC, laundering_edges DESC
LIMIT 15;

// Visualize one fan-in hub (paste the top account id, or auto-pick)
MATCH (sender:Account)-[r:SENT]->(receiver:Account)
WITH receiver, count(DISTINCT sender) AS senders, sum(r.laundering) AS laund
WHERE laund >= 8
WITH receiver ORDER BY laund DESC LIMIT 1
MATCH p = (s:Account)-[:SENT {laundering: 1}]->(receiver)
RETURN p;

// ---------------------------------------------------------------------
// TYPOLOGY 3 - CYCLE (round-tripping: money loops back to its origin)
// Variable-length path that starts and ends at the same laundering account,
// with every edge in the loop flagged as laundering.
// ---------------------------------------------------------------------
MATCH path = (a:Account)-[:SENT*2..5]->(a)
WHERE a.laundering = 1
  AND all(r IN relationships(path) WHERE r.laundering = 1)
RETURN [n IN nodes(path) | n.id] AS cycle, length(path) AS hops
LIMIT 5;

// Visualize one cycle
MATCH path = (a:Account)-[:SENT*2..5]->(a)
WHERE a.laundering = 1
  AND all(r IN relationships(path) WHERE r.laundering = 1)
RETURN path
LIMIT 1;

// ---------------------------------------------------------------------
// TYPOLOGY 4 - GATHER-SCATTER (mixing hub: gathers from many, scatters to many)
// A hub with laundering on both the incoming and outgoing side.
// in/out laundering counted separately to avoid join cross-product inflation.
// ---------------------------------------------------------------------
MATCH (hub:Account)
WHERE hub.laundering = 1
OPTIONAL MATCH (s:Account)-[ri:SENT]->(hub)
WITH hub, count(DISTINCT s) AS senders, sum(ri.laundering) AS in_laund
OPTIONAL MATCH (hub)-[ro:SENT]->(r:Account)
WITH hub, senders, in_laund, count(DISTINCT r) AS receivers, sum(ro.laundering) AS out_laund
WHERE senders >= 5 AND receivers >= 5 AND in_laund >= 3 AND out_laund >= 3
RETURN hub.id AS hub, senders, receivers, in_laund, out_laund
ORDER BY (senders + receivers) DESC
LIMIT 15;

// Visualize one gather-scatter hub (two fans joined at the hub)
MATCH p = (s:Account)-[:SENT {laundering: 1}]->(hub:Account {id: '80794B6F0'})-[:SENT {laundering: 1}]->(r:Account)
RETURN p;
