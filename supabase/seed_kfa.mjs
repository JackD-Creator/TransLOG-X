/**
 * TransLOG-X — Seed KFA Reference Data
 * Mengisi kfa_drugs (obat) dan kfa_alkes (alat kesehatan)
 * Data representatif berdasarkan KFA SATUSEHAT Kemkes
 *
 * Jalankan PERTAMA sebelum seed lainnya:
 *   node supabase/seed_kfa.mjs
 */
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://eccermneumcskamtitqh.supabase.co'
const SERVICE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU'

const sb = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
})

// ─── KFA DRUGS (Obat-obatan) ──────────────────────────────────────────────────
const KFA_DRUGS = [
  // Analgesik / Antipiretik
  { kfa_code: 'KFA-93000005', name: 'Paracetamol', nama_dagang: 'Sanmol', generik: true, dosage_form: 'Tablet', strength: '500 mg', manufacturer: 'PT Sanbe Farma', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 1200, het_price: 1500, uom: 'tablet', is_fornas: true, kelas_terapi: 'Analgesik-Antipiretik', active_ingredients: 'Parasetamol 500mg' },
  { kfa_code: 'KFA-93000006', name: 'Paracetamol', nama_dagang: 'Panadol', generik: true, dosage_form: 'Tablet', strength: '500 mg', manufacturer: 'PT GlaxoSmithKline Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 1800, het_price: 2200, uom: 'tablet', is_fornas: true, kelas_terapi: 'Analgesik-Antipiretik', active_ingredients: 'Parasetamol 500mg' },
  { kfa_code: 'KFA-93000010', name: 'Paracetamol', nama_dagang: 'Tempra Sirup', generik: true, dosage_form: 'Sirup', strength: '160 mg/5 mL', manufacturer: 'PT Medifarma Laboratories', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 15000, het_price: 19000, uom: 'botol', is_fornas: true, kelas_terapi: 'Analgesik-Antipiretik', active_ingredients: 'Parasetamol 160mg/5mL' },
  { kfa_code: 'KFA-93001001', name: 'Ibuprofen', nama_dagang: 'Brufen', generik: true, dosage_form: 'Tablet', strength: '400 mg', manufacturer: 'PT Abbott Indonesia', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 3500, het_price: 4500, uom: 'tablet', is_fornas: true, kelas_terapi: 'NSAID', active_ingredients: 'Ibuprofen 400mg' },
  { kfa_code: 'KFA-93001002', name: 'Ibuprofen', nama_dagang: 'Proris Suspensi', generik: true, dosage_form: 'Suspensi', strength: '100 mg/5 mL', manufacturer: 'PT Konimex', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 25000, het_price: 32000, uom: 'botol', is_fornas: true, kelas_terapi: 'NSAID', active_ingredients: 'Ibuprofen 100mg/5mL' },
  { kfa_code: 'KFA-93001010', name: 'Metamizol Sodium', nama_dagang: 'Novalgin', generik: false, dosage_form: 'Tablet', strength: '500 mg', manufacturer: 'PT Sanofi Indonesia', distributor: 'PT Bina San Prima', fix_price: 2800, het_price: 3500, uom: 'tablet', is_fornas: false, kelas_terapi: 'Analgesik', active_ingredients: 'Metamizol Sodium 500mg' },
  { kfa_code: 'KFA-93001015', name: 'Ketorolac Trometamin', nama_dagang: 'Toradol Injeksi', generik: false, dosage_form: 'Injeksi', strength: '30 mg/mL', manufacturer: 'PT Roche Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 35000, het_price: 45000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Analgesik NSAID', active_ingredients: 'Ketorolac 30mg/mL' },
  { kfa_code: 'KFA-93001020', name: 'Tramadol Hidroklorid', nama_dagang: 'Tramal', generik: false, dosage_form: 'Kapsul', strength: '50 mg', manufacturer: 'PT Grünenthal Pharma', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 8500, het_price: 11000, uom: 'kapsul', is_fornas: true, kelas_terapi: 'Analgesik Opioid', active_ingredients: 'Tramadol HCl 50mg' },

  // Antibiotik
  { kfa_code: 'KFA-93002001', name: 'Amoksisilin', nama_dagang: 'Amoxsan', generik: true, dosage_form: 'Kapsul', strength: '500 mg', manufacturer: 'PT Sanbe Farma', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 2500, het_price: 3200, uom: 'kapsul', is_fornas: true, kelas_terapi: 'Antibiotik Penisilin', active_ingredients: 'Amoksisilin 500mg' },
  { kfa_code: 'KFA-93002002', name: 'Amoksisilin + Asam Klavulanat', nama_dagang: 'Augmentin', generik: false, dosage_form: 'Tablet', strength: '625 mg', manufacturer: 'PT GlaxoSmithKline Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 18500, het_price: 24000, uom: 'tablet', is_fornas: true, kelas_terapi: 'Antibiotik Penisilin+Beta-laktamase Inhibitor', active_ingredients: 'Amoksisilin 500mg + Asam Klavulanat 125mg' },
  { kfa_code: 'KFA-93002010', name: 'Sefotaksim', nama_dagang: 'Claforan', generik: false, dosage_form: 'Injeksi', strength: '1 g', manufacturer: 'PT Sanofi Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 85000, het_price: 110000, uom: 'vial', is_fornas: true, kelas_terapi: 'Antibiotik Sefalosporin Generasi III', active_ingredients: 'Sefotaksim Sodium 1g' },
  { kfa_code: 'KFA-93002011', name: 'Seftriakson', nama_dagang: 'Rocephin', generik: false, dosage_form: 'Injeksi', strength: '1 g', manufacturer: 'PT Roche Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 145000, het_price: 185000, uom: 'vial', is_fornas: true, kelas_terapi: 'Antibiotik Sefalosporin Generasi III', active_ingredients: 'Seftriakson 1g' },
  { kfa_code: 'KFA-93002020', name: 'Siprofloksasin', nama_dagang: 'Ciproxin', generik: true, dosage_form: 'Tablet', strength: '500 mg', manufacturer: 'PT Bayer Indonesia', distributor: 'PT Bina San Prima', fix_price: 4500, het_price: 5800, uom: 'tablet', is_fornas: true, kelas_terapi: 'Antibiotik Fluorokuinolon', active_ingredients: 'Siprofloksasin HCl 500mg' },
  { kfa_code: 'KFA-93002025', name: 'Metronidazol', nama_dagang: 'Flagyl', generik: true, dosage_form: 'Tablet', strength: '500 mg', manufacturer: 'PT Sanofi Indonesia', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 2200, het_price: 2800, uom: 'tablet', is_fornas: true, kelas_terapi: 'Antibiotik Nitroimidazol', active_ingredients: 'Metronidazol 500mg' },
  { kfa_code: 'KFA-93002026', name: 'Metronidazol', nama_dagang: 'Infus Metronidazol', generik: true, dosage_form: 'Infus', strength: '500 mg/100 mL', manufacturer: 'PT Otsuka Indonesia', distributor: 'PT Otsuka Indonesia', fix_price: 35000, het_price: 45000, uom: 'botol', is_fornas: true, kelas_terapi: 'Antibiotik Nitroimidazol', active_ingredients: 'Metronidazol 500mg/100mL' },
  { kfa_code: 'KFA-93002030', name: 'Azitromisin', nama_dagang: 'Zithromax', generik: false, dosage_form: 'Kapsul', strength: '500 mg', manufacturer: 'PT Pfizer Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 28000, het_price: 36000, uom: 'kapsul', is_fornas: true, kelas_terapi: 'Antibiotik Makrolida', active_ingredients: 'Azitromisin 500mg' },
  { kfa_code: 'KFA-93002040', name: 'Meropenem', nama_dagang: 'Meronem', generik: false, dosage_form: 'Injeksi', strength: '1 g', manufacturer: 'PT AstraZeneca Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 450000, het_price: 580000, uom: 'vial', is_fornas: true, kelas_terapi: 'Antibiotik Karbapenem', active_ingredients: 'Meropenem 1g' },

  // Kardiovaskular
  { kfa_code: 'KFA-93003001', name: 'Amlodipin Besilat', nama_dagang: 'Norvasc', generik: true, dosage_form: 'Tablet', strength: '10 mg', manufacturer: 'PT Pfizer Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 8500, het_price: 11000, uom: 'tablet', is_fornas: true, kelas_terapi: 'Calcium Channel Blocker', active_ingredients: 'Amlodipin Besilat 10mg' },
  { kfa_code: 'KFA-93003002', name: 'Amlodipin Besilat', nama_dagang: 'Norvask 5', generik: true, dosage_form: 'Tablet', strength: '5 mg', manufacturer: 'PT Pfizer Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 5500, het_price: 7200, uom: 'tablet', is_fornas: true, kelas_terapi: 'Calcium Channel Blocker', active_ingredients: 'Amlodipin Besilat 5mg' },
  { kfa_code: 'KFA-93003010', name: 'Bisoprolol Fumarat', nama_dagang: 'Concor', generik: true, dosage_form: 'Tablet', strength: '5 mg', manufacturer: 'PT Merck Tbk', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 9800, het_price: 13000, uom: 'tablet', is_fornas: true, kelas_terapi: 'Beta Blocker', active_ingredients: 'Bisoprolol Fumarat 5mg' },
  { kfa_code: 'KFA-93003020', name: 'Lisinopril', nama_dagang: 'Zestril', generik: true, dosage_form: 'Tablet', strength: '10 mg', manufacturer: 'PT AstraZeneca Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 7200, het_price: 9500, uom: 'tablet', is_fornas: true, kelas_terapi: 'ACE Inhibitor', active_ingredients: 'Lisinopril 10mg' },
  { kfa_code: 'KFA-93003030', name: 'Atorvastatin Kalsium', nama_dagang: 'Lipitor', generik: true, dosage_form: 'Tablet', strength: '20 mg', manufacturer: 'PT Pfizer Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 12000, het_price: 15500, uom: 'tablet', is_fornas: true, kelas_terapi: 'Statin', active_ingredients: 'Atorvastatin Kalsium 20mg' },
  { kfa_code: 'KFA-93003040', name: 'Furosemid', nama_dagang: 'Lasix', generik: true, dosage_form: 'Tablet', strength: '40 mg', manufacturer: 'PT Sanofi Indonesia', distributor: 'PT Bina San Prima', fix_price: 1800, het_price: 2400, uom: 'tablet', is_fornas: true, kelas_terapi: 'Diuretik Loop', active_ingredients: 'Furosemid 40mg' },
  { kfa_code: 'KFA-93003041', name: 'Furosemid', nama_dagang: 'Lasix Injeksi', generik: true, dosage_form: 'Injeksi', strength: '10 mg/mL', manufacturer: 'PT Sanofi Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 22000, het_price: 28000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Diuretik Loop', active_ingredients: 'Furosemid 10mg/mL' },
  { kfa_code: 'KFA-93003050', name: 'Digoksin', nama_dagang: 'Lanoxin', generik: true, dosage_form: 'Tablet', strength: '0.25 mg', manufacturer: 'PT GlaxoSmithKline Indonesia', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 3500, het_price: 4500, uom: 'tablet', is_fornas: true, kelas_terapi: 'Glikosida Jantung', active_ingredients: 'Digoksin 0.25mg' },

  // Diabetes / Metabolik
  { kfa_code: 'KFA-93004001', name: 'Metformin Hidroklorid', nama_dagang: 'Glucophage', generik: true, dosage_form: 'Tablet', strength: '500 mg', manufacturer: 'PT Merck Tbk', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 2800, het_price: 3600, uom: 'tablet', is_fornas: true, kelas_terapi: 'Antidiabetik Biguanida', active_ingredients: 'Metformin HCl 500mg' },
  { kfa_code: 'KFA-93004002', name: 'Metformin Hidroklorid', nama_dagang: 'Glucophage XR', generik: true, dosage_form: 'Tablet SR', strength: '750 mg', manufacturer: 'PT Merck Tbk', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 5500, het_price: 7000, uom: 'tablet', is_fornas: true, kelas_terapi: 'Antidiabetik Biguanida', active_ingredients: 'Metformin HCl 750mg' },
  { kfa_code: 'KFA-93004010', name: 'Glibenklamid', nama_dagang: 'Daonil', generik: true, dosage_form: 'Tablet', strength: '5 mg', manufacturer: 'PT Sanofi Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 1500, het_price: 2000, uom: 'tablet', is_fornas: true, kelas_terapi: 'Antidiabetik Sulfonilurea', active_ingredients: 'Glibenklamid 5mg' },
  { kfa_code: 'KFA-93004020', name: 'Insulin Glargin', nama_dagang: 'Lantus', generik: false, dosage_form: 'Injeksi', strength: '100 IU/mL', manufacturer: 'PT Sanofi Indonesia', distributor: 'PT Bina San Prima', fix_price: 385000, het_price: 490000, uom: 'vial', is_fornas: true, kelas_terapi: 'Insulin Basal', active_ingredients: 'Insulin Glargin 100 IU/mL' },
  { kfa_code: 'KFA-93004021', name: 'Insulin Aspart', nama_dagang: 'Novorapid', generik: false, dosage_form: 'Injeksi', strength: '100 IU/mL', manufacturer: 'PT Novo Nordisk Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 350000, het_price: 445000, uom: 'vial', is_fornas: true, kelas_terapi: 'Insulin Prandial', active_ingredients: 'Insulin Aspart 100 IU/mL' },

  // GI & Gastro
  { kfa_code: 'KFA-93005001', name: 'Omeprazol', nama_dagang: 'Losec', generik: true, dosage_form: 'Kapsul', strength: '20 mg', manufacturer: 'PT AstraZeneca Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 8500, het_price: 11000, uom: 'kapsul', is_fornas: true, kelas_terapi: 'Proton Pump Inhibitor', active_ingredients: 'Omeprazol 20mg' },
  { kfa_code: 'KFA-93005002', name: 'Pantoprazol', nama_dagang: 'Pantoprazole Injeksi', generik: true, dosage_form: 'Injeksi', strength: '40 mg', manufacturer: 'PT Takeda Indonesia', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 95000, het_price: 125000, uom: 'vial', is_fornas: true, kelas_terapi: 'Proton Pump Inhibitor', active_ingredients: 'Pantoprazol 40mg' },
  { kfa_code: 'KFA-93005010', name: 'Ranitidin Hidroklorid', nama_dagang: 'Zantac', generik: true, dosage_form: 'Tablet', strength: '150 mg', manufacturer: 'PT GlaxoSmithKline Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 3200, het_price: 4100, uom: 'tablet', is_fornas: true, kelas_terapi: 'H2 Blocker', active_ingredients: 'Ranitidin HCl 150mg' },
  { kfa_code: 'KFA-93005020', name: 'Ondansetron', nama_dagang: 'Zofran', generik: true, dosage_form: 'Tablet', strength: '8 mg', manufacturer: 'PT GlaxoSmithKline Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 25000, het_price: 32000, uom: 'tablet', is_fornas: true, kelas_terapi: 'Antiemetik 5-HT3 Antagonis', active_ingredients: 'Ondansetron HCl 8mg' },
  { kfa_code: 'KFA-93005021', name: 'Ondansetron', nama_dagang: 'Zofran Injeksi', generik: true, dosage_form: 'Injeksi', strength: '4 mg/2 mL', manufacturer: 'PT GlaxoSmithKline Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 45000, het_price: 58000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Antiemetik 5-HT3 Antagonis', active_ingredients: 'Ondansetron HCl 4mg/2mL' },

  // Respirasi
  { kfa_code: 'KFA-93006001', name: 'Salbutamol Sulfat', nama_dagang: 'Ventolin', generik: true, dosage_form: 'Tablet', strength: '4 mg', manufacturer: 'PT GlaxoSmithKline Indonesia', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 2800, het_price: 3600, uom: 'tablet', is_fornas: true, kelas_terapi: 'Beta-2 Agonis', active_ingredients: 'Salbutamol Sulfat 4mg' },
  { kfa_code: 'KFA-93006002', name: 'Salbutamol Sulfat', nama_dagang: 'Ventolin Nebules', generik: true, dosage_form: 'Nebulisasi', strength: '2.5 mg/2.5 mL', manufacturer: 'PT GlaxoSmithKline Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 22000, het_price: 28000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Beta-2 Agonis', active_ingredients: 'Salbutamol Sulfat 2.5mg' },
  { kfa_code: 'KFA-93006010', name: 'Deksametason', nama_dagang: 'Dexamethasone Injeksi', generik: true, dosage_form: 'Injeksi', strength: '5 mg/mL', manufacturer: 'PT Kimia Farma Tbk', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 8500, het_price: 11000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Kortikosteroid', active_ingredients: 'Deksametason 5mg/mL' },
  { kfa_code: 'KFA-93006020', name: 'Aminofilin', nama_dagang: 'Aminophylline Injeksi', generik: true, dosage_form: 'Injeksi', strength: '24 mg/mL', manufacturer: 'PT Harsen', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 18500, het_price: 24000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Bronkodilator Xantin', active_ingredients: 'Aminofilin 240mg/10mL' },

  // Cairan Infus & Elektrolit
  { kfa_code: 'KFA-93007001', name: 'Natrium Klorida', nama_dagang: 'NaCl 0.9%', generik: true, dosage_form: 'Infus', strength: '0.9% / 500 mL', manufacturer: 'PT Otsuka Indonesia', distributor: 'PT Otsuka Indonesia', fix_price: 18000, het_price: 23000, uom: 'botol', is_fornas: true, kelas_terapi: 'Cairan Kristaloid', active_ingredients: 'Natrium Klorida 0.9%' },
  { kfa_code: 'KFA-93007002', name: 'Ringer Laktat', nama_dagang: 'Ringer Laktat Infus', generik: true, dosage_form: 'Infus', strength: '500 mL', manufacturer: 'PT Otsuka Indonesia', distributor: 'PT Otsuka Indonesia', fix_price: 22000, het_price: 28000, uom: 'botol', is_fornas: true, kelas_terapi: 'Cairan Kristaloid', active_ingredients: 'Natrium Klorida + Natrium Laktat + KCl + CaCl' },
  { kfa_code: 'KFA-93007003', name: 'Dekstrosa', nama_dagang: 'Dextrose 5%', generik: true, dosage_form: 'Infus', strength: '5% / 500 mL', manufacturer: 'PT Otsuka Indonesia', distributor: 'PT Otsuka Indonesia', fix_price: 20000, het_price: 26000, uom: 'botol', is_fornas: true, kelas_terapi: 'Cairan Nutrisi', active_ingredients: 'Dekstrosa Monohidrat 50g/L' },
  { kfa_code: 'KFA-93007010', name: 'Kalium Klorida', nama_dagang: 'KCl 7.46%', generik: true, dosage_form: 'Injeksi', strength: '7.46% / 25 mL', manufacturer: 'PT Ikapharmindo Putramas', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 35000, het_price: 45000, uom: 'vial', is_fornas: true, kelas_terapi: 'Elektrolit', active_ingredients: 'Kalium Klorida 7.46%' },

  // Neurologi / Psikiatri
  { kfa_code: 'KFA-93008001', name: 'Diazepam', nama_dagang: 'Valium', generik: true, dosage_form: 'Tablet', strength: '5 mg', manufacturer: 'PT Roche Indonesia', distributor: 'PT Bina San Prima', fix_price: 4500, het_price: 5800, uom: 'tablet', is_fornas: true, kelas_terapi: 'Benzodiazepin', active_ingredients: 'Diazepam 5mg', is_psikotropika: true },
  { kfa_code: 'KFA-93008002', name: 'Diazepam', nama_dagang: 'Stesolid Rectal Tube', generik: true, dosage_form: 'Rektal', strength: '10 mg', manufacturer: 'PT Actavis Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 65000, het_price: 85000, uom: 'tube', is_fornas: true, kelas_terapi: 'Benzodiazepin', active_ingredients: 'Diazepam 10mg', is_psikotropika: true },
  { kfa_code: 'KFA-93008010', name: 'Fenitoin Natrium', nama_dagang: 'Dilantin Injeksi', generik: true, dosage_form: 'Injeksi', strength: '50 mg/mL', manufacturer: 'PT Pfizer Indonesia', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 85000, het_price: 110000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Antikonvulsan', active_ingredients: 'Fenitoin Natrium 50mg/mL' },
  { kfa_code: 'KFA-93008020', name: 'Haloperidol', nama_dagang: 'Haldol Injeksi', generik: true, dosage_form: 'Injeksi', strength: '5 mg/mL', manufacturer: 'PT Janssen-Cilag', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 55000, het_price: 72000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Antipsikotik', active_ingredients: 'Haloperidol 5mg/mL' },

  // Hematologi / Koagulasi
  { kfa_code: 'KFA-93009001', name: 'Heparin Natrium', nama_dagang: 'Heparin Injeksi', generik: true, dosage_form: 'Injeksi', strength: '5000 IU/mL', manufacturer: 'PT Pfizer Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 185000, het_price: 240000, uom: 'vial', is_fornas: true, kelas_terapi: 'Antikoagulan', active_ingredients: 'Heparin Natrium 5000 IU/mL' },
  { kfa_code: 'KFA-93009010', name: 'Fitomenadion', nama_dagang: 'Vitamin K1 Injeksi', generik: true, dosage_form: 'Injeksi', strength: '10 mg/mL', manufacturer: 'PT Actavis Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 28000, het_price: 36000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Vitamin K', active_ingredients: 'Fitomenadion 10mg/mL' },

  // Vitamin & Mineral
  { kfa_code: 'KFA-93010001', name: 'Vitamin C', nama_dagang: 'Ascorvit', generik: true, dosage_form: 'Tablet', strength: '250 mg', manufacturer: 'PT Bernofarm', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 850, het_price: 1100, uom: 'tablet', is_fornas: true, kelas_terapi: 'Vitamin', active_ingredients: 'Asam Askorbat 250mg' },
  { kfa_code: 'KFA-93010010', name: 'Vitamin B Kompleks', nama_dagang: 'Neurobion', generik: false, dosage_form: 'Tablet', strength: 'B1 100mg+B6 100mg+B12 200mcg', manufacturer: 'PT Merck Tbk', distributor: 'PT Enseval Putra Megatrading Tbk', fix_price: 3500, het_price: 4500, uom: 'tablet', is_fornas: false, kelas_terapi: 'Vitamin B Kompleks', active_ingredients: 'Vit B1+B6+B12' },
  { kfa_code: 'KFA-93010020', name: 'Zink Sulfat', nama_dagang: 'Zincteral', generik: true, dosage_form: 'Tablet', strength: '20 mg', manufacturer: 'PT Polpharma', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 3200, het_price: 4200, uom: 'tablet', is_fornas: true, kelas_terapi: 'Mineral', active_ingredients: 'Zink Sulfat 45mg (setara Zink 20mg)' },

  // Anastesi & Sedasi
  { kfa_code: 'KFA-93011001', name: 'Ketamin Hidroklorid', nama_dagang: 'Ketalar', generik: true, dosage_form: 'Injeksi', strength: '10 mg/mL', manufacturer: 'PT Pfizer Indonesia', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 95000, het_price: 125000, uom: 'vial', is_fornas: true, kelas_terapi: 'Anestesi Umum', active_ingredients: 'Ketamin HCl 10mg/mL' },
  { kfa_code: 'KFA-93011010', name: 'Propofol', nama_dagang: 'Diprivan', generik: false, dosage_form: 'Injeksi', strength: '10 mg/mL', manufacturer: 'PT AstraZeneca Indonesia', distributor: 'PT Kalbe Farma Tbk', fix_price: 285000, het_price: 365000, uom: 'vial', is_fornas: true, kelas_terapi: 'Anestesi Intravena', active_ingredients: 'Propofol 10mg/mL' },
  { kfa_code: 'KFA-93011020', name: 'Morfin Sulfat', nama_dagang: 'Morfin Injeksi', generik: true, dosage_form: 'Injeksi', strength: '10 mg/mL', manufacturer: 'PT Kimia Farma Tbk', distributor: 'PT Kimia Farma Trading & Distribution', fix_price: 125000, het_price: 165000, uom: 'ampul', is_fornas: true, kelas_terapi: 'Analgesik Opioid Kuat', active_ingredients: 'Morfin Sulfat 10mg/mL', is_narkotika: true },
]

// ─── KFA ALKES (Alat Kesehatan) ───────────────────────────────────────────────
const KFA_ALKES = [
  { kfa_code: 'KFA-ALK-001', name: 'Spuit Injeksi 3 mL', farmalkes_type: 'Alat Suntik', med_dev_jenis: 'Syringe', med_dev_kategori: 'Peralatan Medis Habis Pakai', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Terumo Indonesia', distributor: 'PT Unimed Trading', fix_price: 2500, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-002', name: 'Spuit Injeksi 5 mL', farmalkes_type: 'Alat Suntik', med_dev_jenis: 'Syringe', med_dev_kategori: 'Peralatan Medis Habis Pakai', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Terumo Indonesia', distributor: 'PT Unimed Trading', fix_price: 3200, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-003', name: 'Spuit Injeksi 10 mL', farmalkes_type: 'Alat Suntik', med_dev_jenis: 'Syringe', med_dev_kategori: 'Peralatan Medis Habis Pakai', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Terumo Indonesia', distributor: 'PT Unimed Trading', fix_price: 4500, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-004', name: 'Spuit Insulin 1 mL U-100', farmalkes_type: 'Alat Suntik Insulin', med_dev_jenis: 'Insulin Syringe', med_dev_kategori: 'Peralatan Diabetes', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Becton Dickinson Indonesia', distributor: 'PT Unimed Trading', fix_price: 8500, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-010', name: 'Jarum Infus Butterfly 23G', farmalkes_type: 'Jarum Medis', med_dev_jenis: 'Butterfly Needle', med_dev_kategori: 'Peralatan Medis Habis Pakai', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Nipro Indonesia', distributor: 'PT Unimed Trading', fix_price: 6500, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-011', name: 'Abbocath IV Catheter 20G', farmalkes_type: 'Kateter Intravena', med_dev_jenis: 'IV Catheter', med_dev_kategori: 'Peralatan Medis Habis Pakai', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Abbott Indonesia', distributor: 'PT Unimed Trading', fix_price: 28000, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-012', name: 'Abbocath IV Catheter 18G', farmalkes_type: 'Kateter Intravena', med_dev_jenis: 'IV Catheter', med_dev_kategori: 'Peralatan Medis Habis Pakai', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Abbott Indonesia', distributor: 'PT Unimed Trading', fix_price: 30000, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-020', name: 'Infusion Set Standar', farmalkes_type: 'Selang Infus', med_dev_jenis: 'Infusion Set', med_dev_kategori: 'Peralatan Medis Habis Pakai', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Otsuka Indonesia', distributor: 'PT Otsuka Indonesia', fix_price: 18000, uom: 'set', is_steril: true },
  { kfa_code: 'KFA-ALK-021', name: 'Blood Transfusion Set', farmalkes_type: 'Selang Transfusi', med_dev_jenis: 'Blood Set', med_dev_kategori: 'Peralatan Medis Habis Pakai', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Terumo Indonesia', distributor: 'PT Unimed Trading', fix_price: 35000, uom: 'set', is_steril: true },
  { kfa_code: 'KFA-ALK-030', name: 'Sarung Tangan Lateks Steril No. 7', farmalkes_type: 'Sarung Tangan Medis', med_dev_jenis: 'Surgical Gloves', med_dev_kategori: 'Perlindungan Diri', med_dev_kelas_risiko: 'Kelas I', manufacturer: 'PT Medline Industries', distributor: 'PT Jayamas Medica Industri', fix_price: 12000, uom: 'pair', is_steril: true },
  { kfa_code: 'KFA-ALK-031', name: 'Sarung Tangan Latex Non-Steril (100pcs)', farmalkes_type: 'Sarung Tangan Medis', med_dev_jenis: 'Examination Gloves', med_dev_kategori: 'Perlindungan Diri', med_dev_kelas_risiko: 'Kelas I', manufacturer: 'PT Medline Industries', distributor: 'PT Jayamas Medica Industri', fix_price: 180000, uom: 'box', is_steril: false },
  { kfa_code: 'KFA-ALK-040', name: 'Masker Bedah 3-ply (50pcs)', farmalkes_type: 'Alat Pelindung Diri', med_dev_jenis: 'Surgical Mask', med_dev_kategori: 'Perlindungan Diri', med_dev_kelas_risiko: 'Kelas I', manufacturer: 'PT Medline Industries', distributor: 'PT Jayamas Medica Industri', fix_price: 95000, uom: 'box', is_steril: false },
  { kfa_code: 'KFA-ALK-041', name: 'Masker N95 (FFP2)', farmalkes_type: 'Alat Pelindung Diri', med_dev_jenis: 'N95 Respirator', med_dev_kategori: 'Perlindungan Diri', med_dev_kelas_risiko: 'Kelas II', manufacturer: '3M Indonesia', distributor: 'PT Jayamas Medica Industri', fix_price: 45000, uom: 'pcs', is_steril: false },
  { kfa_code: 'KFA-ALK-050', name: 'Kassa Steril 10x10 (10pcs)', farmalkes_type: 'Pembalut & Penutup Luka', med_dev_jenis: 'Sterile Gauze', med_dev_kategori: 'Perawatan Luka', med_dev_kelas_risiko: 'Kelas I', manufacturer: 'PT Medika Lestari', distributor: 'PT Jayamas Medica Industri', fix_price: 12500, uom: 'pack', is_steril: true },
  { kfa_code: 'KFA-ALK-051', name: 'Plester Luka Hypafix 10cm x 10m', farmalkes_type: 'Pembalut & Penutup Luka', med_dev_jenis: 'Medical Tape', med_dev_kategori: 'Perawatan Luka', med_dev_kelas_risiko: 'Kelas I', manufacturer: 'PT BSN Medical', distributor: 'PT Jayamas Medica Industri', fix_price: 185000, uom: 'roll', is_steril: false },
  { kfa_code: 'KFA-ALK-060', name: 'Urine Catheter Fr 16', farmalkes_type: 'Kateter Urin', med_dev_jenis: 'Foley Catheter', med_dev_kategori: 'Kateter & Drainase', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Tyco Healthcare Indonesia', distributor: 'PT Unimed Trading', fix_price: 45000, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-070', name: 'Nasogastric Tube Fr 16', farmalkes_type: 'Selang NGT', med_dev_jenis: 'Nasogastric Tube', med_dev_kategori: 'Selang & Drainase', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Vygon Indonesia', distributor: 'PT Unimed Trading', fix_price: 38000, uom: 'pcs', is_steril: true },
  { kfa_code: 'KFA-ALK-080', name: 'Blood Glucose Strip (50pcs)', farmalkes_type: 'Strip Diagnostik', med_dev_jenis: 'Glucose Test Strip', med_dev_kategori: 'Diagnostik In Vitro', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Roche Indonesia', distributor: 'PT Roche Indonesia', fix_price: 285000, uom: 'box', is_steril: false },
  { kfa_code: 'KFA-ALK-090', name: 'Oksimeter Pulse Digital', farmalkes_type: 'Monitor Pasien', med_dev_jenis: 'Pulse Oximeter', med_dev_kategori: 'Peralatan Monitor', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Mindray Indonesia', distributor: 'PT Unimed Trading', fix_price: 850000, uom: 'unit', is_steril: false },
  { kfa_code: 'KFA-ALK-100', name: 'Tensimeter Digital', farmalkes_type: 'Alat Ukur Tekanan Darah', med_dev_jenis: 'Blood Pressure Monitor', med_dev_kategori: 'Peralatan Diagnostik', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Omron Healthcare Indonesia', distributor: 'PT Unimed Trading', fix_price: 1250000, uom: 'unit', is_steril: false },
  { kfa_code: 'KFA-ALK-110', name: 'Nebulizer Kompresor', farmalkes_type: 'Peralatan Terapi Pernafasan', med_dev_jenis: 'Nebulizer', med_dev_kategori: 'Peralatan Terapi', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Pari GmbH Indonesia', distributor: 'PT Unimed Trading', fix_price: 985000, uom: 'unit', is_steril: false },
  { kfa_code: 'KFA-ALK-120', name: 'Masker Oksigen Dewasa', farmalkes_type: 'Aksesoris Oksigen', med_dev_jenis: 'Oxygen Mask', med_dev_kategori: 'Terapi Oksigen', med_dev_kelas_risiko: 'Kelas I', manufacturer: 'PT Hudson RCI Indonesia', distributor: 'PT Jayamas Medica Industri', fix_price: 45000, uom: 'pcs', is_steril: false },
  { kfa_code: 'KFA-ALK-130', name: 'Benang Jahit Absorbable (Chromic Catgut 2-0)', farmalkes_type: 'Benang Bedah', med_dev_jenis: 'Surgical Suture', med_dev_kategori: 'Bedah', med_dev_kelas_risiko: 'Kelas III', manufacturer: 'PT Ethicon Johnson & Johnson', distributor: 'PT Unimed Trading', fix_price: 185000, uom: 'pack', is_steril: true },
  { kfa_code: 'KFA-ALK-140', name: 'Rapid Antigen Test COVID-19', farmalkes_type: 'Alat Uji Cepat', med_dev_jenis: 'Rapid Test', med_dev_kategori: 'Diagnostik In Vitro', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT SD Biosensor Indonesia', distributor: 'PT Jayamas Medica Industri', fix_price: 45000, uom: 'pcs', is_steril: false },
  { kfa_code: 'KFA-ALK-150', name: 'Elektroda EKG (10 lead)', farmalkes_type: 'Aksesoris EKG', med_dev_jenis: 'ECG Electrode', med_dev_kategori: 'Diagnostik Kardiologi', med_dev_kelas_risiko: 'Kelas II', manufacturer: 'PT Nikomed', distributor: 'PT Unimed Trading', fix_price: 85000, uom: 'set', is_steril: false },
]

async function seed() {
  console.log('🌱 Seeding KFA reference data...\n')

  // Check apakah sudah ada
  const { count: existingDrugs } = await sb.from('kfa_drugs').select('id', { count: 'exact', head: true })
  const { count: existingAlkes } = await sb.from('kfa_alkes').select('id', { count: 'exact', head: true })

  console.log(`📊 Existing: ${existingDrugs} drugs, ${existingAlkes} alkes`)

  // Seed kfa_drugs
  console.log(`\n🔄 Seeding ${KFA_DRUGS.length} obat ke kfa_drugs...`)
  const { error: e1 } = await sb.from('kfa_drugs')
    .upsert(KFA_DRUGS.map(d => ({
      kfa_code: d.kfa_code,
      name: d.name,
      nama_dagang: d.nama_dagang ?? null,
      generik: d.generik ?? true,
      active_ingredients: d.active_ingredients ?? null,
      dosage_form: d.dosage_form ?? null,
      strength: d.strength ?? null,
      manufacturer: d.manufacturer ?? null,
      distributor: d.distributor ?? null,
      fix_price: d.fix_price ?? null,
      het_price: d.het_price ?? null,
      uom: d.uom ?? 'tablet',
      is_fornas: d.is_fornas ?? false,
      is_narkotika: d.is_narkotika ?? false,
      is_psikotropika: d.is_psikotropika ?? false,
      kelas_terapi: d.kelas_terapi ?? null,
    })), { onConflict: 'kfa_code' })

  if (e1) { console.error('❌ kfa_drugs error:', e1.message) }
  else { console.log(`✅ ${KFA_DRUGS.length} obat berhasil di-seed`) }

  // Seed kfa_alkes
  console.log(`\n🔄 Seeding ${KFA_ALKES.length} alkes ke kfa_alkes...`)
  const { error: e2 } = await sb.from('kfa_alkes')
    .upsert(KFA_ALKES.map(d => ({
      kfa_code: d.kfa_code,
      name: d.name,
      farmalkes_type: d.farmalkes_type ?? null,
      med_dev_jenis: d.med_dev_jenis ?? null,
      med_dev_kategori: d.med_dev_kategori ?? null,
      med_dev_kelas_risiko: d.med_dev_kelas_risiko ?? null,
      manufacturer: d.manufacturer ?? null,
      distributor: d.distributor ?? null,
      fix_price: d.fix_price ?? null,
      uom: d.uom ?? 'pcs',
      is_steril: d.is_steril ?? false,
    })), { onConflict: 'kfa_code' })

  if (e2) { console.error('❌ kfa_alkes error:', e2.message) }
  else { console.log(`✅ ${KFA_ALKES.length} alkes berhasil di-seed`) }

  console.log('\n✅ Seed KFA selesai!')
  console.log('   Jalankan seed_ecosystem.mjs untuk mengisi supplier_catalog_items')
}

seed().catch(console.error)
