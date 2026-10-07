abstract interface class AccountDeletionService {
  Future<void> deleteAccount(Set<String> socialAccounts);
}
