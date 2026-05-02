import '../models/appointment.dart';
import '../models/calendar_data.dart';
import '../models/profile_data.dart';
import '../models/credit_pack.dart';
import '../models/buyable_credit.dart';
import '../models/invoice.dart';
import '../models/metric_history.dart';
import '../models/performance_section.dart';
import '../models/trainer.dart';
import '../models/training_type.dart';

class MockData {
  static StartData get startData => StartData(
        firstName: 'Max',
        lastName: 'Mustermann',
        totalCredits: 6,
        appointments: [
          Appointment(
            id: '1',
            startDate: DateTime.now().add(const Duration(days: 2, hours: 9)),
            duration: 60,
            text: 'Bitte Kettlebells vorbereiten',
            trainingTypeId: '1',
            trainingTypeName: 'Personal Training',
            locationId: '1',
            locationName: 'Sihl Training Zuerich',
            trainerId: '7',
            trainerName: 'Stefan Meier',
            creditsCharged: 2,
            status: 'booked',
          ),
          Appointment(
            id: '2',
            startDate: DateTime.now().add(const Duration(days: 5, hours: 10)),
            duration: 60,
            text: '',
            trainingTypeId: '2',
            trainingTypeName: 'Kraft & Ausdauer',
            locationId: '1',
            locationName: 'Sihl Training Zuerich',
            trainerId: '7',
            trainerName: 'Stefan Meier',
            creditsCharged: 2,
            status: 'booked',
          ),
          Appointment(
            id: '3',
            startDate: DateTime.now().add(const Duration(days: 9, hours: 8)),
            duration: 60,
            text: 'Fokus auf Ruecken',
            trainingTypeId: '1',
            trainingTypeName: 'Personal Training',
            locationId: '1',
            locationName: 'Sihl Training Zuerich',
            trainerId: '8',
            trainerName: 'Anna Keller',
            creditsCharged: 2,
            status: 'booked',
          ),
        ],
      );

  static CalendarData get calendarData {
    final trainers = [
      Trainer(id: '7', firstName: 'Stefan', lastName: 'Meier', shortName: 'SM'),
      Trainer(id: '8', firstName: 'Anna', lastName: 'Keller', shortName: 'AK'),
    ];
    final types = [
      TrainingType(id: '1', name: 'Personal Training', duration: 3600),
      TrainingType(id: '2', name: 'Kraft & Ausdauer', duration: 3600),
      TrainingType(id: '3', name: 'Yoga & Mobility', duration: 3600),
    ];
    return CalendarData(
      defaultTrainerId: '7',
      defaultTypeId: '1',
      minimumDate: DateTime.now().subtract(const Duration(days: 30)),
      maximumDate: DateTime.now().add(const Duration(days: 60)),
      trainers: trainers,
      trainingTypes: types,
      appointments: startData.appointments,
      availabilityIntervals: [],
    );
  }

  static ProfileData get profileData => ProfileData(
        firstName: 'Max',
        lastName: 'Mustermann',
        imageUrl: null,
        creditPacks: [
          CreditPack(
            title: '10er Abo Personal Training',
            prepaidCredits: 10,
            spentCredits: 7,
            expiryDate: DateTime.now().add(const Duration(days: 90)),
          ),
          CreditPack(
            title: '5er Abo Kraft & Ausdauer',
            prepaidCredits: 5,
            spentCredits: 2,
            expiryDate: DateTime.now().add(const Duration(days: 180)),
          ),
        ],
      );

  static List<ClientCredit> get clientCredits => [
        ClientCredit(
          id: '1',
          title: '10er Abo Personal Training',
          paid: 10,
          attended: 7,
          remaining: 3,
          startdate: '2026-01-01',
          expires: '2026-06-30',
        ),
        ClientCredit(
          id: '2',
          title: '5er Abo Kraft & Ausdauer',
          paid: 5,
          attended: 2,
          remaining: 3,
          startdate: '2026-02-01',
          expires: '2026-12-31',
        ),
      ];

  static List<BuyableCredit> get buyableCredits => [
        BuyableCredit(
          creditId: 'ST-10',
          name: '10er Abo Personal Training',
          desc: '10 Einheiten a 60 Minuten Personal Training',
          unit: '10 Einheiten',
          price: 990.00,
        ),
      ];

  static List<Invoice> get invoices => [
        Invoice(
          invoiceNumber: 'RE-2026-042',
          status: 'bezahlt',
          transactionDate: DateTime(2026, 3, 1),
          dueDate: DateTime(2026, 3, 15),
          currency: 'CHF',
          amount: 990.00,
        ),
        Invoice(
          invoiceNumber: 'RE-2026-021',
          status: 'bezahlt',
          transactionDate: DateTime(2026, 2, 1),
          dueDate: DateTime(2026, 2, 15),
          currency: 'CHF',
          amount: 420.00,
        ),
        Invoice(
          invoiceNumber: 'RE-2026-008',
          status: 'offen',
          transactionDate: DateTime(2026, 1, 15),
          dueDate: DateTime(2026, 4, 30),
          currency: 'CHF',
          amount: 560.00,
        ),
        Invoice(
          invoiceNumber: 'RE-2025-198',
          status: 'bezahlt',
          transactionDate: DateTime(2025, 12, 1),
          dueDate: DateTime(2025, 12, 15),
          currency: 'CHF',
          amount: 990.00,
        ),
      ];

  static Map<String, List<MetricHistoryPoint>> get performanceHistory => {};

  static List<PerformanceSection> get performanceData => [
        PerformanceSection(
          title: 'Koerperkomposition',
          items: [
            PerformanceItem(name: 'Gewicht', value: '78.4 kg', previousValue: '80.1 kg', change: '-1.7'),
            PerformanceItem(name: 'Koerperfett', value: '14.2 %', previousValue: '16.0 %', change: '-1.8'),
            PerformanceItem(name: 'Muskelmasse', value: '62.1 kg', previousValue: '60.8 kg', change: '+1.3'),
            PerformanceItem(name: 'BMI', value: '22.8', previousValue: '23.3', change: '-0.5'),
          ],
        ),
        PerformanceSection(
          title: 'Kraft',
          items: [
            PerformanceItem(name: 'Kniebeuge (1RM)', value: '110 kg', previousValue: '100 kg', change: '+10'),
            PerformanceItem(name: 'Bankdruecken (1RM)', value: '85 kg', previousValue: '80 kg', change: '+5'),
            PerformanceItem(name: 'Kreuzheben (1RM)', value: '140 kg', previousValue: '130 kg', change: '+10'),
          ],
        ),
        PerformanceSection(
          title: 'Ausdauer',
          items: [
            PerformanceItem(name: 'Ruhepuls', value: '58 bpm', previousValue: '63 bpm', change: '-5'),
          ],
        ),
      ];
}
