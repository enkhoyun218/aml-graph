# Get the IBM AML dataset before building

1. Go to Kaggle: **IBM Transactions for Anti Money Laundering (AML)**
   https://www.kaggle.com/datasets/ealtman2019/ibm-transactions-for-anti-money-laundering-aml
2. Download and unzip into THIS folder (`aml-graph/data/`). **Start with the HI-Small files** to keep it fast:
   - `HI-Small_Trans.csv` — the transactions (sender/receiver accounts, amount, currency, timestamp, Is Laundering flag)
   - `HI-Small_Patterns.txt` — the list of transactions that form each of the 8 laundering typologies
3. You can scale up to Medium/Large later if time allows.

Notes:
- Columns include: Timestamp, From Bank + Account, To Bank + Account, Amount Received/Paid, Receiving/Payment Currency, Payment Format, and **Is Laundering** (0/1).
- Keep these CSVs OUT of Git (they're large). A `.gitignore` will exclude `data/*.csv`.
- The `Patterns.txt` file is how you validate your Cypher typology queries against known laundering structures.
