import 'package:intl/intl.dart';

String formatPrice(double price) {
  // This creates a format with a space (' ') as a grouping separator
  var formatter = NumberFormat('#,###', 'en_US');
  
  // We manually replace the comma with a space to get the Uzbek style
  return '${formatter.format(price).replaceAll(',', ' ')} sum';
}