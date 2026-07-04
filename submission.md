# 📊 Submission Banking Transaction Analytics

Dokumen ini berisi kumpulan query analitik untuk mengevaluasi performa transaksi, nasabah, cabang, channel, produk, serta mendeteksi potensi risiko dan fraud pada data perbankan.

---

# 📑 Daftar Isi

1. [Transaction Analytics](#01-transaction-analytics-)
2. [Customer 360](#02-customer-360-)
3. [Branch Performance](#03-branch-performance-)
4. [Channel Analysis](#04-channel-analysis-)
5. [Product Performance](#05-product-performance-)
6. [Risk & Fraud Detection](#06-risk--fraud-detection-)
7. [Summary](#-summary)

---

# 01. Transaction Analytics 📈

## 🎯 Business Question

**Berapa total volume dan nilai transaksi per hari, minggu, dan bulan? Apa tren pertumbuhannya?**

---

## 01.a. Tren Harian

Mengukur volume transaksi, total nilai transaksi, dan pertumbuhan harian dibandingkan hari sebelumnya.

```sql
SELECT
    dd.full_date AS tanggal,
    COUNT(ft.transaction_id) AS total_volume,
    SUM(ft.amount) AS total_nilai,
    LAG(SUM(ft.amount)) OVER (ORDER BY dd.full_date) AS nilai_hari_lalu,
    ROUND(
        (SUM(ft.amount) - LAG(SUM(ft.amount)) OVER (ORDER BY dd.full_date)) /
        NULLIF(LAG(SUM(ft.amount)) OVER (ORDER BY dd.full_date), 0) * 100,
    2) AS persentase_pertumbuhan
FROM fact_transactions ft
JOIN dim_date dd ON ft.date_key = dd.date_key
WHERE ft.status = 'SUCCESS'
GROUP BY dd.full_date
ORDER BY dd.full_date;
```

### 📄 Hasil Query

➡️ [01_a.csv](./results/01_a.csv)

---

## 01.b. Tren Bulanan

Mengukur performa transaksi bulanan serta pertumbuhan terhadap bulan sebelumnya.

```sql
SELECT
    dd.year AS tahun,
    dd.month_name AS bulan,
    COUNT(ft.transaction_id) AS total_volume,
    SUM(ft.amount) AS total_nilai,
    LAG(SUM(ft.amount)) OVER (ORDER BY dd.year, dd.month) AS nilai_bulan_lalu,
    ROUND(
        (SUM(ft.amount) - LAG(SUM(ft.amount)) OVER (ORDER BY dd.year, dd.month)) /
        NULLIF(LAG(SUM(ft.amount)) OVER (ORDER BY dd.year, dd.month), 0) * 100,
    2) AS persentase_pertumbuhan
FROM fact_transactions ft
JOIN dim_date dd ON ft.date_key = dd.date_key
WHERE ft.status = 'SUCCESS'
GROUP BY dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month;
```

### 📄 Hasil Query

➡️ [01_b.csv](./results/01_b.csv)

---

## 01.c. Tren Tahunan

Mengukur pertumbuhan transaksi tahunan (Year-over-Year Growth).

```sql
SELECT
    dd.year AS tahun,
    COUNT(ft.transaction_id) AS total_volume,
    SUM(ft.amount) AS total_nilai,
    LAG(SUM(ft.amount)) OVER (ORDER BY dd.year) AS nilai_tahun_lalu,
    ROUND(
        (SUM(ft.amount) - LAG(SUM(ft.amount)) OVER (ORDER BY dd.year)) /
        NULLIF(LAG(SUM(ft.amount)) OVER (ORDER BY dd.year), 0) * 100,
    2) AS persentase_pertumbuhan
FROM fact_transactions ft
JOIN dim_date dd ON ft.date_key = dd.date_key
WHERE ft.status = 'SUCCESS'
GROUP BY dd.year
ORDER BY dd.year;
```

### 📄 Hasil Query

➡️ [01_c.csv](./results/01_c.csv)

---

# 02. Customer 360 👥

## 🎯 Business Question

**Siapa nasabah paling aktif berdasarkan frekuensi dan nilai transaksi? Bagaimana distribusi per segmen nasabah?**

---

## 02.a. Top 10 Nasabah Paling Aktif

Menampilkan 10 nasabah dengan total nilai transaksi tertinggi.

```sql
SELECT
    dc.customer_id,
    dc.full_name,
    dc.segment,
    COUNT(ft.transaction_id) AS frekuensi_transaksi,
    SUM(ft.amount) AS total_nilai_transaksi
FROM fact_transactions ft
JOIN dim_customers dc ON ft.customer_key = dc.customer_key
WHERE ft.status = 'SUCCESS'
GROUP BY dc.customer_id, dc.full_name, dc.segment
ORDER BY total_nilai_transaksi DESC
LIMIT 10;
```

### 📄 Hasil Query

➡️ [02_a.csv](./results/02_a.csv)

---

## 02.b. Distribusi Performa per Segmen Nasabah

Membandingkan performa transaksi berdasarkan segmen nasabah:

* Retail
* Priority
* VIP

```sql
SELECT
    dc.segment,
    COUNT(DISTINCT dc.customer_id) AS jumlah_unik_nasabah,
    COUNT(ft.transaction_id) AS total_volume_transaksi,
    SUM(ft.amount) AS total_nilai_transaksi
FROM fact_transactions ft
JOIN dim_customers dc ON ft.customer_key = dc.customer_key
WHERE ft.status = 'SUCCESS'
GROUP BY dc.segment
ORDER BY total_nilai_transaksi DESC;
```

### 📄 Hasil Query

➡️ [02_b.csv](./results/02_b.csv)

---

# 03. Branch Performance 🏢

## 🎯 Business Question

**Cabang mana yang memiliki performa tertinggi berdasarkan jumlah transaksi dan total nilai transaksi pada setiap region?**

```sql
WITH RankedBranches AS (
    SELECT
        db.region,
        db.branch_name,
        COUNT(ft.transaction_id) AS total_transaksi,
        SUM(ft.amount) AS total_nilai,
        RANK() OVER (
            PARTITION BY db.region
            ORDER BY SUM(ft.amount) DESC
        ) AS rank_di_region
    FROM fact_transactions ft
    JOIN dim_branches db ON ft.branch_key = db.branch_key
    WHERE ft.status = 'SUCCESS'
    GROUP BY db.region, db.branch_name
)
SELECT
    region,
    branch_name,
    total_transaksi,
    total_nilai
FROM RankedBranches
WHERE rank_di_region = 1
ORDER BY total_nilai DESC;
```

### 📄 Hasil Query

➡️ [3.csv](./results/3.csv)

---

# 04. Channel Analysis 📱

## 🎯 Business Question

**Channel apa yang paling banyak digunakan nasabah? Bagaimana tren migrasi ke channel digital?**

### Channel yang Dianalisis

* ATM
* Mobile Banking
* Internet Banking
* Teller
* EDC / Mesin Kasir
* Call Center / IVR

```sql
SELECT
    dd.year,
    dd.quarter,
    dch.channel_name,
    dch.is_digital,
    COUNT(ft.transaction_id) AS volume_penggunaan,
    SUM(ft.amount) AS total_nilai
FROM fact_transactions ft
JOIN dim_channels dch ON ft.channel_key = dch.channel_key
JOIN dim_date dd ON ft.date_key = dd.date_key
WHERE ft.status = 'SUCCESS'
GROUP BY
    dd.year,
    dd.quarter,
    dch.channel_name,
    dch.is_digital
ORDER BY
    dd.year,
    dd.quarter,
    volume_penggunaan DESC;
```

### 📄 Hasil Query

➡️ [4.csv](./results/4.csv)

---

# 05. Product Performance 💳

## 🎯 Business Question

**Produk rekening mana yang menghasilkan volume transaksi dan saldo rata-rata tertinggi?**

### Produk yang Dianalisis

* Tabungan
* Giro
* Deposito

```sql
SELECT
    da.account_type,
    da.product_name,
    COUNT(ft.transaction_id) AS volume_transaksi,
    ROUND(AVG(ft.balance_after), 2) AS saldo_rata_rata
FROM fact_transactions ft
JOIN dim_accounts da ON ft.account_key = da.account_key
WHERE ft.status = 'SUCCESS'
GROUP BY da.account_type, da.product_name
ORDER BY volume_transaksi DESC;
```

### 📄 Hasil Query

➡️ [5.csv](./results/5.csv)

---

# 06. Risk & Fraud Detection 🚨

## 🎯 Business Question

**Apakah terdapat transaksi anomali yang berpotensi mengindikasikan fraud atau aktivitas mencurigakan?**

---

## 06.a. Failed Transaction Repetition

### Threshold

* Gagal transaksi lebih dari 5 kali

```sql
SELECT
    dc.customer_id,
    dc.full_name,
    COUNT(ft.transaction_id) AS jumlah_gagal,
    SUM(ft.amount) AS potensi_nilai_gagal
FROM fact_transactions ft
JOIN dim_customers dc ON ft.customer_key = dc.customer_key
WHERE ft.status = 'FAILED'
GROUP BY dc.customer_id, dc.full_name
HAVING COUNT(ft.transaction_id) > 5
ORDER BY jumlah_gagal DESC;
```

### 📄 Hasil Query

➡️ [6_a.csv](./results/6_a.csv)

---

## 06.b. Velocity Abuse Detection

### Indikasi

* Frekuensi transaksi tidak wajar
* Nilai transaksi sangat besar dalam satu hari

### Threshold

* Frekuensi transaksi > 15 transaksi/hari
* Total transaksi > Rp1.000.000.000/hari

```sql
SELECT
    dd.full_date,
    dc.customer_id,
    dc.full_name,
    COUNT(ft.transaction_id) AS frekuensi_harian,
    SUM(ft.amount) AS nilai_transaksi_harian
FROM fact_transactions ft
JOIN dim_customers dc ON ft.customer_key = dc.customer_key
JOIN dim_date dd ON ft.date_key = dd.date_key
WHERE ft.status = 'SUCCESS'
GROUP BY
    dd.full_date,
    dc.customer_id,
    dc.full_name
HAVING
    COUNT(ft.transaction_id) > 15
    OR SUM(ft.amount) > 1000000000
ORDER BY nilai_transaksi_harian DESC;
```

### 📄 Hasil Query

Tidak terdapat data yang memenuhi kriteria velocity abuse, sehingga tidak ditemukan indikasi transaksi mencurigakan berdasarkan threshold yang digunakan.

---

# 📌 Summary

| Area                   | Objective                                     |
| ---------------------- | --------------------------------------------- |
| Transaction Analytics  | Analisis tren volume dan nilai transaksi      |
| Customer 360           | Identifikasi nasabah bernilai tinggi          |
| Branch Performance     | Evaluasi performa cabang per region           |
| Channel Analysis       | Analisis adopsi channel digital               |
| Product Performance    | Evaluasi performa produk perbankan            |
| Risk & Fraud Detection | Identifikasi aktivitas mencurigakan dan fraud |

---

## ✅ Dataset Output

| Query                   | CSV Result                     |
| ----------------------- | ------------------------------ |
| 01.a Tren Harian        | [01_a.csv](./results/01_a.csv) |
| 01.b Tren Bulanan       | [01_b.csv](./results/01_b.csv) |
| 01.c Tren Tahunan       | [01_c.csv](./results/01_c.csv) |
| 02.a Top Nasabah        | [02_a.csv](./results/02_a.csv) |
| 02.b Segment Analysis   | [02_b.csv](./results/02_b.csv) |
| 03 Branch Performance   | [3.csv](./results/3.csv)       |
| 04 Channel Analysis     | [4.csv](./results/4.csv)       |
| 05 Product Performance  | [5.csv](./results/5.csv)       |
| 06.a Failed Transaction | [6_a.csv](./results/6_a.csv)   |
| 06.b Velocity Abuse     | Tidak ada data                 |

```
```
