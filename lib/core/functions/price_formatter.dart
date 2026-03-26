String formatPrice(double value) {
  final price = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  var counter = 0;
  for (var i = price.length - 1; i >= 0; i--) {
    counter++;
    buffer.write(price[i]);
    if (counter == 3 && i != 0) {
      buffer.write(' ');
      counter = 0;
    }
  }
  return '${buffer.toString().split('').reversed.join()} ₸';
}
