enum BlendMode {
  normal('Normal'),
  darken('Darken'),
  multiply('Multiply'),
  colorBurn('Color Burn'),
  linearBurn('Linear Burn'),
  lighten('Lighten'),
  screen('Screen'),
  colorDodge('Color Dodge'),
  linearDodge('Linear Dodge (Add)'),
  overlay('Overlay'),
  softLight('Soft Light'),
  hardLight('Hard Light'),
  vividLight('Vivid Light'),
  linearLight('Linear Light'),
  pinLight('Pin Light'),
  hardMix('Hard Mix'),
  difference('Difference'),
  exclusion('Exclusion'),
  subtract('Subtract'),
  divide('Divide'),
  hue('Hue'),
  saturation('Saturation'),
  color('Color'),
  luminosity('Luminosity');

  final String jsonName;
  const BlendMode(this.jsonName);

  static BlendMode fromJson(String name) {
    return BlendMode.values.firstWhere(
      (e) => e.jsonName == name,
      orElse: () => BlendMode.normal,
    );
  }

  String toJson() => jsonName;

  String get displayName => jsonName;

  int get nativeValue => index;
}