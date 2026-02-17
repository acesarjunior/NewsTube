
/// Decodifica entidades HTML comuns (ex.: &#39;, &quot;, &amp;) para texto normal.
/// Implementação leve, sem dependências externas.
String decodeHtmlEntities(String? input) {
  if (input == null) return '';

  var s = input;

  // Primeiro, entidades nomeadas comuns
  s = s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');

  // Entidades numéricas decimais: &#1234;
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '');
    if (code == null) return m.group(0) ?? '';
    return String.fromCharCode(code);
  });

  // Entidades numéricas hex: &#x1F600;
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '', radix: 16);
    if (code == null) return m.group(0) ?? '';
    return String.fromCharCode(code);
  });

  return s;
}
