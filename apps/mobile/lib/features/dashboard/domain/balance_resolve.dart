/// Statement/account balance when available; otherwise explicit unknown as `0`.
double resolveTotalBalance(double? balanceFromColumn) {
  if (balanceFromColumn != null && !balanceFromColumn.isNaN) {
    return balanceFromColumn;
  }
  return 0;
}
