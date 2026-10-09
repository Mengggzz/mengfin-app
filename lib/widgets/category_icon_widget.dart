import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/utils.dart';

/// Helper mapping kategori ke SVG icon aset kategori
final Map<String, String> _kategoriSvgMap = {
  'Makan & Minum': 'assets/icons/category/fast-food.svg',
  'Makanan': 'assets/icons/category/fast-food.svg',
  'Transportasi': 'assets/icons/category/suv.svg',
  'Belanja': 'assets/icons/category/shopping-cart.svg',
  'Hiburan': 'assets/icons/category/joystick.svg',
  'Kesehatan': 'assets/icons/category/health-check.svg',
  'Pendidikan': 'assets/icons/category/books.svg',
  'Tagihan': 'assets/icons/category/bill.svg',
  'Kerja': 'assets/icons/category/laptop.svg',
  'Pajak & Asuransi': 'assets/icons/category/insurance.svg',
  'Sosial': 'assets/icons/category/high-five.svg',
  'Keluarga': 'assets/icons/category/family.svg',
  'Pakaian': 'assets/icons/category/clothes-hanger.svg',
  'Perawatan': 'assets/icons/category-custom/perfume.svg',
  'Olahraga': 'assets/icons/category/sports.svg',
  'Pemeliharaan': 'assets/icons/category-custom/kitchen-tool.svg',
  'Rumah Tangga': 'assets/icons/category/house.svg',
  'Kendaraan': 'assets/icons/category-custom/car.svg',
  'Koreksi (-)': 'assets/icons/category/adjustment.svg',
  'Lainnya': 'assets/icons/category/more.svg',
  'Gaji': 'assets/icons/category/salary.svg',
  'Bonus': 'assets/icons/category/bonus.svg',
  'Investasi': 'assets/icons/category/investment.svg',
  'Transfer': 'assets/icons/category/exchange.svg',
};

/// Widget render ikon kategori MengFin (SVG dengan fallback Emoji)
class CategoryIconWidget extends StatelessWidget {
  final String kategori;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final double? padding;
  final double borderRadius;

  const CategoryIconWidget({
    super.key,
    required this.kategori,
    this.size = 24.0,
    this.color,
    this.backgroundColor,
    this.padding,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final info = getKategoriInfo(kategori);
    final svgPath = _kategoriSvgMap[kategori];
    final iconColor = color ?? Color(info.color);

    Widget iconWidget;
    if (svgPath != null) {
      iconWidget = SvgPicture.asset(
        svgPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        placeholderBuilder: (_) => Text(
          info.icon,
          style: TextStyle(fontSize: size * 0.8),
        ),
      );
    } else {
      iconWidget = Text(
        info.icon,
        style: TextStyle(fontSize: size * 0.8),
      );
    }

    if (backgroundColor != null || padding != null) {
      return Container(
        padding: EdgeInsets.all(padding ?? 6.0),
        decoration: BoxDecoration(
          color: backgroundColor ?? iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}
