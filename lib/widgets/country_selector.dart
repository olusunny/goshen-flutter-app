import 'package:flutter/material.dart';

class CountrySelector extends StatelessWidget {
  const CountrySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Country of residence',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  static const countries = <String>[
    'Nigeria',
    'United Kingdom',
    'United States',
    'Canada',
    'Ghana',
    'South Africa',
    'Ireland',
    'Germany',
    'France',
    'Italy',
    'Spain',
    'Netherlands',
    'Australia',
    'United Arab Emirates',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = countries.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      items: countries
          .map((country) => DropdownMenuItem<String>(
                value: country,
                child: Text('${countryFlag(country)} $country'),
              ))
          .toList(),
      onChanged: (country) {
        if (country != null) onChanged(country);
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          Icons.public_rounded,
          color: isDark ? const Color(0xFFFFC857) : const Color(0xFF0C2230),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8EC),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFFB522), width: 1.4),
        ),
      ),
      dropdownColor: isDark ? const Color(0xFF102532) : Colors.white,
    );
  }
}

class StateProvinceSelector extends StatelessWidget {
  const StateProvinceSelector({
    super.key,
    required this.country,
    required this.value,
    required this.onChanged,
    this.label = 'State / county / province',
  });

  final String country;
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = statesForCountry(country);
    final selected = options.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      items: options
          .map((state) => DropdownMenuItem<String>(
                value: state,
                child: Text(state),
              ))
          .toList(),
      onChanged: (state) {
        if (state != null) onChanged(state);
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          Icons.map_rounded,
          color: isDark ? const Color(0xFFFFC857) : const Color(0xFF0C2230),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8EC),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFFB522), width: 1.4),
        ),
      ),
      dropdownColor: isDark ? const Color(0xFF102532) : Colors.white,
    );
  }
}

List<String> statesForCountry(String? country) {
  switch ((country ?? '').trim().toLowerCase()) {
    case 'nigeria':
      return const [
        'Abia',
        'Adamawa',
        'Akwa Ibom',
        'Anambra',
        'Bauchi',
        'Bayelsa',
        'Benue',
        'Borno',
        'Cross River',
        'Delta',
        'Ebonyi',
        'Edo',
        'Ekiti',
        'Enugu',
        'FCT Abuja',
        'Gombe',
        'Imo',
        'Jigawa',
        'Kaduna',
        'Kano',
        'Katsina',
        'Kebbi',
        'Kogi',
        'Kwara',
        'Lagos',
        'Nasarawa',
        'Niger',
        'Ogun',
        'Ondo',
        'Osun',
        'Oyo',
        'Plateau',
        'Rivers',
        'Sokoto',
        'Taraba',
        'Yobe',
        'Zamfara',
      ];
    case 'united kingdom':
      return const ['England', 'Scotland', 'Wales', 'Northern Ireland'];
    case 'united states':
      return const [
        'Alabama',
        'Alaska',
        'Arizona',
        'Arkansas',
        'California',
        'Colorado',
        'Connecticut',
        'Florida',
        'Georgia',
        'Illinois',
        'Maryland',
        'Massachusetts',
        'New Jersey',
        'New York',
        'North Carolina',
        'Ohio',
        'Pennsylvania',
        'Texas',
        'Virginia',
        'Washington',
        'Other',
      ];
    case 'canada':
      return const [
        'Alberta',
        'British Columbia',
        'Manitoba',
        'New Brunswick',
        'Newfoundland and Labrador',
        'Nova Scotia',
        'Ontario',
        'Prince Edward Island',
        'Quebec',
        'Saskatchewan',
        'Other',
      ];
    case 'ghana':
      return const [
        'Ashanti',
        'Bono',
        'Central',
        'Eastern',
        'Greater Accra',
        'Northern',
        'Volta',
        'Western',
        'Other',
      ];
    case 'south africa':
      return const [
        'Eastern Cape',
        'Free State',
        'Gauteng',
        'KwaZulu-Natal',
        'Limpopo',
        'Mpumalanga',
        'Northern Cape',
        'North West',
        'Western Cape',
      ];
    case 'australia':
      return const [
        'Australian Capital Territory',
        'New South Wales',
        'Northern Territory',
        'Queensland',
        'South Australia',
        'Tasmania',
        'Victoria',
        'Western Australia',
      ];
    default:
      return const ['Not applicable', 'Other'];
  }
}

String countryFlag(String? country) {
  switch ((country ?? '').trim().toLowerCase()) {
    case 'nigeria':
      return '🇳🇬';
    case 'united kingdom':
      return '🇬🇧';
    case 'united states':
      return '🇺🇸';
    case 'canada':
      return '🇨🇦';
    case 'ghana':
      return '🇬🇭';
    case 'south africa':
      return '🇿🇦';
    case 'ireland':
      return '🇮🇪';
    case 'germany':
      return '🇩🇪';
    case 'france':
      return '🇫🇷';
    case 'italy':
      return '🇮🇹';
    case 'spain':
      return '🇪🇸';
    case 'netherlands':
      return '🇳🇱';
    case 'australia':
      return '🇦🇺';
    case 'united arab emirates':
      return '🇦🇪';
    default:
      return '🌍';
  }
}
