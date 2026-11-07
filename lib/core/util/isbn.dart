/// ISBN-13 book prefix and EAN check digit. Ignore product and price barcodes.
bool isBookIsbn13(String? value) {
  if (value == null || !RegExp(r'^(978|979)\d{10}$').hasMatch(value)) {
    return false;
  }
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    sum += int.parse(value[i]) * (i.isEven ? 1 : 3);
  }
  return sum % 10 == 0;
}
