import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/amount_expression.dart';

void main() {
  group('AmountExpression.evaluate', () {
    test('angka tunggal dihitung sebagai dirinya sendiri', () {
      expect(AmountExpression.evaluate('25000'), 25000);
      expect(AmountExpression.evaluate('0'), 0);
    });

    test('penjumlahan — bukan penggabungan digit', () {
      // Ini bug lama: "25 + 10" dulu tersimpan sebagai 2510.
      expect(AmountExpression.evaluate('25 + 10'), 35);
      expect(AmountExpression.evaluate('1000 + 250'), 1250);
    });

    test('pengurangan, perkalian, pembagian', () {
      expect(AmountExpression.evaluate('100 - 30'), 70);
      expect(AmountExpression.evaluate('1000 × 3'), 3000);
      expect(AmountExpression.evaluate('1000 ÷ 4'), 250);
    });

    test('× dan ÷ dihitung sebelum + dan -', () {
      expect(AmountExpression.evaluate('2 + 3 × 4'), 14);
      expect(AmountExpression.evaluate('10 + 8 ÷ 2'), 14);
      expect(AmountExpression.evaluate('100 - 2 × 10'), 80);
    });

    test('dihitung kiri ke kanan untuk operator setingkat', () {
      expect(AmountExpression.evaluate('10 - 2 - 3'), 5);
      expect(AmountExpression.evaluate('100 ÷ 5 ÷ 2'), 10);
    });

    test('ekspresi belum lengkap → null, tidak menebak', () {
      expect(AmountExpression.evaluate('25 +'), isNull);
      expect(AmountExpression.evaluate('25 + '), isNull);
      expect(AmountExpression.evaluate('+'), isNull);
      expect(AmountExpression.evaluate(''), isNull);
      expect(AmountExpression.evaluate('   '), isNull);
    });

    test('ekspresi tidak sah → null', () {
      expect(AmountExpression.evaluate('25 abc 10'), isNull);
      expect(AmountExpression.evaluate('25 ++ 10'), isNull);
      expect(AmountExpression.evaluate('25 + + 10'), isNull);
      expect(AmountExpression.evaluate('..5'), isNull);
    });

    test('pembagian dengan nol → null (bukan Infinity)', () {
      expect(AmountExpression.evaluate('100 ÷ 0'), isNull);
    });
  });

  group('AmountExpression helper', () {
    test('isOperator mengenali keempat tombol numpad', () {
      expect(AmountExpression.isOperator('+'), isTrue);
      expect(AmountExpression.isOperator('-'), isTrue);
      expect(AmountExpression.isOperator('×'), isTrue);
      expect(AmountExpression.isOperator('÷'), isTrue);
      expect(AmountExpression.isOperator('7'), isFalse);
      expect(AmountExpression.isOperator(' '), isFalse);
    });

    test('endsWithOperator tahu kapan menunggu angka', () {
      expect(AmountExpression.endsWithOperator('25 +'), isTrue);
      expect(AmountExpression.endsWithOperator('25 + '), isTrue);
      expect(AmountExpression.endsWithOperator('25 + 1'), isFalse);
      expect(AmountExpression.endsWithOperator('25000'), isFalse);
      expect(AmountExpression.endsWithOperator(''), isFalse);
    });

    test('hasOperator membedakan angka biasa dari ekspresi', () {
      expect(AmountExpression.hasOperator('25000'), isFalse);
      expect(AmountExpression.hasOperator('25 + 10'), isTrue);
    });

    test('lastNumber memberi angka terakhir yang diketik', () {
      expect(AmountExpression.lastNumber('25 + '), 25);
      expect(AmountExpression.lastNumber('25 + 1'), 1);
      expect(AmountExpression.lastNumber('25000'), 25000);
      expect(AmountExpression.lastNumber('+'), isNull);
    });

    test('formatNumber menghasilkan isi input yang bersih', () {
      expect(AmountExpression.formatNumber(35), '35');
      expect(AmountExpression.formatNumber(250.0), '250');
      expect(AmountExpression.formatNumber(12.5), '12.5');
      expect(AmountExpression.formatNumber(0), '0');
    });
  });
}
