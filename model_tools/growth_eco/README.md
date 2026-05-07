# Growth Eco Adapter Notes

`Patent_fishi.py` contains the reference ecology and growth simulation logic. The current request path does not execute it directly because the script is monolithic and includes plotting side effects.

The future adapter should expose a pure function interface that returns JSON-compatible outputs for:

- fish count `N`
- individual weight `W`
- biomass `B`
- feed `F`
- temperature `T`
- DO
- TN
- TP
- chlorophyll `C`
- cumulative nitrogen and phosphorus emissions

The current mock adapter already borrows:

- the 25C temperature optimum
- the logistic-style growth intuition
- oxygen-aware growth degradation
