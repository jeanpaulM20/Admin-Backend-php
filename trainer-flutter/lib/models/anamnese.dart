class Anamnese {
  final int? clientId;
  String? address;
  String? profession;
  int? activities;         // 0=Sitzend, 1=Mässig, 2=Intensiv
  int? physicalDemands;    // 0-4 scale (PHP enum)
  String? sportarts;
  String? sportartsScope;
  int? sportartsIntensity; // 0=Leicht, 1=Moderat, 2=Anstrengend
  int? sleepWeek;          // hours per night
  int? sleepWeekend;       // hours per night
  String? relaxationWeek;
  String? relaxationWeekend;
  String? trainingDayoff;
  bool? injury;
  String? injuryType;
  String? injuryBodypart;
  bool? injuryChronic;
  bool? diseaseHeartattack;
  bool? diseaseArterialDisorder;
  bool? diseaseRaynaldSyndrome;
  bool? diseaseVasculitis;
  bool? diseaseColdSensitivity;
  bool? diseaseSensoryDisturbances;
  bool? diseaseCirculatoryDisorder;
  bool? diseaseNerveDamage;
  bool? diseaseReplantation;
  bool? diseasePeripheralLymphatics;
  bool? diseaseHemoglobinemia;
  bool? diseaseKidneyBladder;
  bool? diseaseHeartCirculatory;
  bool? musculoskeletalProblems;
  String? musculoskeletalProblemsDescription;
  String? comments;
  String? goals;
  bool? medicalTreatment;
  bool? takingDrugs;

  Anamnese({
    this.clientId,
    this.address,
    this.profession,
    this.activities,
    this.physicalDemands,
    this.sportarts,
    this.sportartsScope,
    this.sportartsIntensity,
    this.sleepWeek,
    this.sleepWeekend,
    this.relaxationWeek,
    this.relaxationWeekend,
    this.trainingDayoff,
    this.injury,
    this.injuryType,
    this.injuryBodypart,
    this.injuryChronic,
    this.diseaseHeartattack,
    this.diseaseArterialDisorder,
    this.diseaseRaynaldSyndrome,
    this.diseaseVasculitis,
    this.diseaseColdSensitivity,
    this.diseaseSensoryDisturbances,
    this.diseaseCirculatoryDisorder,
    this.diseaseNerveDamage,
    this.diseaseReplantation,
    this.diseasePeripheralLymphatics,
    this.diseaseHemoglobinemia,
    this.diseaseKidneyBladder,
    this.diseaseHeartCirculatory,
    this.musculoskeletalProblems,
    this.musculoskeletalProblemsDescription,
    this.comments,
    this.goals,
    this.medicalTreatment,
    this.takingDrugs,
  });

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.toInt();
    return null;
  }

  static bool? _parseBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return null;
  }

  factory Anamnese.fromJson(Map<String, dynamic> json) {
    return Anamnese(
      clientId: json['client_id'] is int
          ? json['client_id']
          : int.tryParse(json['client_id']?.toString() ?? ''),
      address: json['address']?.toString(),
      profession: json['profession']?.toString(),
      activities: _parseInt(json['activities']),
      physicalDemands: _parseInt(json['physical_demands']),
      sportarts: json['sportarts']?.toString(),
      sportartsScope: json['sportarts_scope']?.toString(),
      sportartsIntensity: _parseInt(json['sportarts_intencity']),
      sleepWeek: _parseInt(json['sleep_week']),
      sleepWeekend: _parseInt(json['sleep_weekend']),
      relaxationWeek: json['relaxation_week']?.toString(),
      relaxationWeekend: json['relaxation_weekend']?.toString(),
      trainingDayoff: json['training_dayoff']?.toString(),
      injury: _parseBool(json['injury']),
      injuryType: json['injury_type']?.toString(),
      injuryBodypart: json['injury_bodypart']?.toString(),
      injuryChronic: _parseBool(json['injury_chronic']),
      diseaseHeartattack: _parseBool(json['disease_heartattack']),
      diseaseArterialDisorder: _parseBool(json['disease_arterial_disorder']),
      diseaseRaynaldSyndrome: _parseBool(json['disease_raynauld_syndrome']),
      diseaseVasculitis: _parseBool(json['disease_vasculitis']),
      diseaseColdSensitivity: _parseBool(json['disease_cold_sensitivity']),
      diseaseSensoryDisturbances:
          _parseBool(json['disease_sensory_disturbances']),
      diseaseCirculatoryDisorder:
          _parseBool(json['disease_circulatory_disorder']),
      diseaseNerveDamage: _parseBool(json['disease_nerve_damage']),
      diseaseReplantation: _parseBool(json['disease_replantation']),
      diseasePeripheralLymphatics:
          _parseBool(json['disease_peripheral_lymphatics']),
      diseaseHemoglobinemia: _parseBool(json['disease_hemoglobinemia']),
      diseaseKidneyBladder: _parseBool(json['disease_kidney_bladder']),
      diseaseHeartCirculatory: _parseBool(json['disease_heart_circulatory']),
      musculoskeletalProblems: _parseBool(json['musculoskeletal_problems']),
      musculoskeletalProblemsDescription:
          json['musculoskeletal_problems_description']?.toString(),
      comments: json['comments']?.toString(),
      goals: json['goals']?.toString(),
      medicalTreatment: _parseBool(json['medical_treatment']),
      takingDrugs: _parseBool(json['taking_drugs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (clientId != null) 'client_id': clientId,
      if (address != null) 'address': address,
      if (profession != null) 'profession': profession,
      'activities': activities ?? 0,
      'physical_demands': physicalDemands ?? 0,
      if (sportarts != null) 'sportarts': sportarts,
      if (sportartsScope != null) 'sportarts_scope': sportartsScope,
      'sportarts_intencity': sportartsIntensity ?? 0,
      'sleep_week': sleepWeek ?? 0,
      'sleep_weekend': sleepWeekend ?? 0,
      if (relaxationWeek != null) 'relaxation_week': relaxationWeek,
      if (relaxationWeekend != null) 'relaxation_weekend': relaxationWeekend,
      if (trainingDayoff != null) 'training_dayoff': trainingDayoff,
      if (injury != null) 'injury': injury! ? 1 : 0,
      if (injuryType != null) 'injury_type': injuryType,
      if (injuryBodypart != null) 'injury_bodypart': injuryBodypart,
      if (injuryChronic != null) 'injury_chronic': injuryChronic! ? 1 : 0,
      if (diseaseHeartattack != null)
        'disease_heartattack': diseaseHeartattack! ? 1 : 0,
      if (diseaseArterialDisorder != null)
        'disease_arterial_disorder': diseaseArterialDisorder! ? 1 : 0,
      if (diseaseRaynaldSyndrome != null)
        'disease_raynauld_syndrome': diseaseRaynaldSyndrome! ? 1 : 0,
      if (diseaseVasculitis != null)
        'disease_vasculitis': diseaseVasculitis! ? 1 : 0,
      if (diseaseColdSensitivity != null)
        'disease_cold_sensitivity': diseaseColdSensitivity! ? 1 : 0,
      if (diseaseSensoryDisturbances != null)
        'disease_sensory_disturbances': diseaseSensoryDisturbances! ? 1 : 0,
      if (diseaseCirculatoryDisorder != null)
        'disease_circulatory_disorder': diseaseCirculatoryDisorder! ? 1 : 0,
      if (diseaseNerveDamage != null)
        'disease_nerve_damage': diseaseNerveDamage! ? 1 : 0,
      if (diseaseReplantation != null)
        'disease_replantation': diseaseReplantation! ? 1 : 0,
      if (diseasePeripheralLymphatics != null)
        'disease_peripheral_lymphatics': diseasePeripheralLymphatics! ? 1 : 0,
      if (diseaseHemoglobinemia != null)
        'disease_hemoglobinemia': diseaseHemoglobinemia! ? 1 : 0,
      if (diseaseKidneyBladder != null)
        'disease_kidney_bladder': diseaseKidneyBladder! ? 1 : 0,
      if (diseaseHeartCirculatory != null)
        'disease_heart_circulatory': diseaseHeartCirculatory! ? 1 : 0,
      if (musculoskeletalProblems != null)
        'musculoskeletal_problems': musculoskeletalProblems! ? 1 : 0,
      if (musculoskeletalProblemsDescription != null)
        'musculoskeletal_problems_description':
            musculoskeletalProblemsDescription,
      if (comments != null) 'comments': comments,
      if (goals != null) 'goals': goals,
      if (medicalTreatment != null)
        'medical_treatment': medicalTreatment! ? 1 : 0,
      if (takingDrugs != null) 'taking_drugs': takingDrugs! ? 1 : 0,
    };
  }
}
