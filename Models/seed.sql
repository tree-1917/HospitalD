-- Seed data for hospital system with Arabic names
-- Doctors
INSERT INTO
  doctors (username, email)
VALUES
  ('dr_ahmad', 'ahmad@hospital.com'),
  ('dr_fatima', 'fatima@hospital.com'),
  ('dr_khalid', 'khalid@hospital.com'),
  ('dr_noura', 'noura@hospital.com'),
  ('dr_youssef', 'youssef@hospital.com');

-- Patients
INSERT INTO
  patients (username, email, doctor_id, summary)
VALUES
  (
    'omar_ali',
    'omar@mail.com',
    1,
    '{"condition": "انفلونزا", "notes": "راحة مطلوبة", "blood_type": "A+"}'
  ),
  (
    'sara_mohammed',
    'sara@mail.com',
    1,
    '{"condition": "فحص دوري", "notes": "سنوي", "blood_type": "O-"}'
  ),
  (
    'layla_hassan',
    'layla@mail.com',
    2,
    '{"condition": "صداع مزمن", "notes": "مراجعة بعد اسبوع", "blood_type": "B+"}'
  ),
  (
    'kareem_said',
    'kareem@mail.com',
    2,
    '{"condition": "كسر في اليد", "notes": "جبس مطلوب", "blood_type": "AB+"}'
  ),
  (
    'nadia_ibrahim',
    'nadia@mail.com',
    3,
    '{"condition": "حساسية", "notes": "تجنب الغبار", "blood_type": "A-"}'
  ),
  (
    'tariq_omar',
    'tariq@mail.com',
    3,
    '{"condition": "ضغط مرتفع", "notes": "متابعة يومية", "blood_type": "O+"}'
  ),
  (
    'amal_khalid',
    'amal@mail.com',
    4,
    '{"condition": "سكري", "notes": "نظام غذائي", "blood_type": "B-"}'
  ),
  (
    'hassan_youssef',
    'hassan@mail.com',
    4,
    '{"condition": "آلام ظهر", "notes": "علاج طبيعي", "blood_type": "A+"}'
  ),
  (
    'mona_fathi',
    'mona@mail.com',
    5,
    '{"condition": "فحص عيون", "notes": "نظارة جديدة", "blood_type": "O-"}'
  ),
  (
    'yassin_ahmad',
    'yassin@mail.com',
    5,
    '{"condition": "تهيج جلدي", "notes": "مرهم موصوف", "blood_type": "AB-"}'
  ),
  (
    'reem_salim',
    'reem@mail.com',
    1,
    '{"condition": "تعب عام", "notes": "تحاليل دم", "blood_type": "A+"}'
  ),
  (
    'fadi_nasser',
    'fadi@mail.com',
    2,
    '{"condition": "كحة مستمرة", "notes": "اشعة صدر", "blood_type": "O+"}'
  ),
  (
    'dina_ramzi',
    'dina@mail.com',
    3,
    '{"condition": "دوخة", "notes": "فحص اذن", "blood_type": "B+"}'
  ),
  (
    'samir_talal',
    'samir@mail.com',
    4,
    '{"condition": "التهاب مفاصل", "notes": "علاج مسكن", "blood_type": "A-"}'
  ),
  (
    'ghada_majid',
    'ghada@mail.com',
    5,
    '{"condition": "فحص اسنان", "notes": "حشو مطلوب", "blood_type": "O-"}'
  );

-- Clerks
INSERT INTO
  clerks (username, email, doctor_id)
VALUES
  ('clerk_faisal', 'faisal@hospital.com', 1),
  ('clerk_lina', 'lina@hospital.com', 2),
  ('clerk_tamer', 'tamer@hospital.com', 3),
  ('clerk_rania', 'rania@hospital.com', 4),
  ('clerk_bassam', 'bassam@hospital.com', 5);

-- Recipes (medical bills)
INSERT INTO
  recipes (doctor_id, patient_id, title, price, status)
VALUES
  (1, 1, 'فحص انفلونزا', 150.00, 'pending'),
  (1, 1, 'تحليل دم', 75.00, 'paid'),
  (1, 11, 'فحص عام', 200.00, 'pending'),
  (2, 3, 'فحص صداع', 180.00, 'paid'),
  (2, 4, 'جبس يد', 350.00, 'pending'),
  (2, 12, 'اشعة صدر', 220.00, 'paid'),
  (3, 5, 'فحص حساسية', 120.00, 'pending'),
  (3, 6, 'فحص ضغط', 90.00, 'paid'),
  (3, 13, 'فحص اذن', 160.00, 'pending'),
  (4, 7, 'فحص سكري', 200.00, 'paid'),
  (4, 8, 'جلسة علاج طبيعي', 250.00, 'pending'),
  (4, 14, 'مسكن مفاصل', 80.00, 'paid'),
  (5, 9, 'فحص عيون', 300.00, 'pending'),
  (5, 10, 'مرهم جلدي', 45.00, 'paid'),
  (5, 15, 'حشو اسنان', 400.00, 'pending'),
  (1, 2, 'فحص سنوي', 175.00, 'paid'),
  (2, 3, 'متابعة صداع', 100.00, 'pending'),
  (3, 6, 'متابعة ضغط', 85.00, 'paid'),
  (4, 7, 'متابعة سكري', 150.00, 'pending'),
  (5, 9, 'نظارة طبية', 500.00, 'paid');
