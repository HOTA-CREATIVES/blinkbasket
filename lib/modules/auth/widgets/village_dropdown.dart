import 'package:flutter/material.dart';

class VillageDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  
  static const List<String> villages = [
    'Bhimavaram',
    'Veeravasaram',
    'Rayakuduru',
    'Srungavruksham',
    'Mentada',
  ];

  const VillageDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          hint: const Text(
            'Select your Village / గ్రామం ఎంచుకోండి',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.green),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          items: villages.map((String village) {
            return DropdownMenuItem<String>(
              value: village,
              child: Text(
                village,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a village';
            }
            return null;
          },
        ),
      ),
    );
  }
}
