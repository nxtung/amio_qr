/// Cấp độ sửa lỗi (Error Correction Level) cho mã QR.
///
/// - [low]: ~7% dữ liệu có thể phục hồi. Mã QR thưa nhất, quét nhanh nhất.
/// - [medium]: ~15% dữ liệu có thể phục hồi (Mặc định).
/// - [quartile]: ~25% dữ liệu có thể phục hồi.
/// - [high]: ~30% dữ liệu có thể phục hồi. Thích hợp khi có nhúng logo ở giữa.
enum QrErrorCorrectionLevel {
  /// Cấp độ L (~7% phục hồi).
  low('L'),

  /// Cấp độ M (~15% phục hồi) - Khuyến nghị mặc định.
  medium('M'),

  /// Cấp độ Q (~25% phục hồi).
  quartile('Q'),

  /// Cấp độ H (~30% phục hồi) - Tốt nhất khi nhúng logo ở trung tâm.
  high('H');

  const QrErrorCorrectionLevel(this.value);

  /// Ký tự đại diện cho cấp độ ('L', 'M', 'Q', 'H').
  final String value;
}
