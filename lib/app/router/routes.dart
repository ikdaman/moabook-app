abstract final class Routes {
  static const splash          = '/';
  static const login           = '/login';
  static const onboarding      = '/onboarding';
  static const signup          = '/signup';
  static const home            = '/main/home';
  static const searchBook      = '/main/search-book';
  static const addBook         = '/add-book';
  static const manualBookInput = '/manual-book-input';
  static const barcode         = '/barcode';
  static const history         = '/main/history';
  static const setting         = '/main/setting';
  static const searchMyBook    = '/main/search-my-book';
  static const _bookInfoBase   = '/main/book-info';

  static String bookInfo(int mybookId) => '$_bookInfoBase/$mybookId';
}
