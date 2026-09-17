class ServiceImageResolver {
  static String? resolveImage(String identifier) {
    final slug = identifier.toLowerCase();

    const assetMap = {
      // Plumbing
      'plumbing': 'assets/images/services/plumbing.jpg',
      'plumber': 'assets/images/services/plumbing.jpg',

      // Electrical
      'electrical': 'assets/images/services/electrical.jpg',
      'electrician': 'assets/images/services/electrical.jpg',
      'electrical_services': 'assets/images/services/electrical.jpg',

      // HVAC / AC Repair
      'hvac': 'assets/images/services/hvac.jpg',
      'ac-repair': 'assets/images/services/hvac.jpg',
      'ac_expert': 'assets/images/services/hvac.jpg',
      'ac-expert': 'assets/images/services/hvac.jpg',

      // Appliance
      'appliance': 'assets/images/services/appliance_repair.jpg',
      'appliance-repair': 'assets/images/services/appliance_repair.jpg',
      'appliance_repair': 'assets/images/services/appliance_repair.jpg',
      'home-appliance': 'assets/images/services/appliance_repair.jpg',
      'home_appliance': 'assets/images/services/appliance_repair.jpg',
      'appliance-pro': 'assets/images/services/appliance_repair.jpg',

      // Carpenter
      'carpentry': 'assets/images/services/carpenter.jpg',
      'carpenter': 'assets/images/services/carpenter.jpg',

      // Cleaning
      'cleaning': 'assets/images/services/cleaning.jpg',
      'cleaning_services': 'assets/images/services/cleaning.jpg',

      // Locksmith
      'locksmith': 'assets/images/services/locksmith.jpg',

      // Handyman
      'handyman': 'assets/images/services/handyman.jpg',

      // Pest Control
      'pest-control': 'assets/images/services/pest_control.jpg',
      'pest_control': 'assets/images/services/pest_control.jpg',
    };

    return assetMap[slug];
  }
}
