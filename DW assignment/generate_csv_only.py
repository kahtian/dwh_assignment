"""
Library Data Warehouse - CSV Generator (CORRECTED FOR 10-YEAR SPAN)
Generates CSV files for bulk loading with academic patterns across all 10 years.
"""

import pandas as pd
import random
import datetime
from faker import Faker
import os

# Configuration
TARGET_VOLUMES = {
    'LOAN_FACT': 150000,
    'SALES_FACT': 120000,
    'PURCHASE_FACT': 100000,
    'RESERVATION_FACT': 200000
}

# Simulate dimension ranges
DIMENSION_RANGES = {
    'date_keys': range(1, 3651),      # 10 years of dates (365 days * 10 years)
    'book_keys': range(1000, 11000),  # 10K books
    'member_keys': range(1000, 11000), # 10K members
    'staff_keys': range(1000, 1021),   # 21 staff (1000 to 1020)
    'supplier_keys': range(1000, 1011)  # 10 suppliers
}

class CSVDataGenerator:
    def __init__(self):
        self.fake = Faker()

    def get_academic_pattern(self, date_key):
        """Determines the academic pattern for a given date_key across a 10-year period."""
        day_of_year = (date_key - 1) % 365 + 1

        # Define day-of-year ranges for academic events
        study_periods = [(6, 12), (139, 145), (272, 278)]
        exam_periods = [(13, 21), (146, 159), (279, 292)]
        semester_starts = [(20, 50), (244, 270)] # Jan/Feb and Sep
        holiday_breaks = [(160, 243), (355, 365)] # Summer and Winter

        for start, end in study_periods:
            if start <= day_of_year <= end:
                return 'study_period'
        for start, end in exam_periods:
            if start <= day_of_year <= end:
                return 'exam_period'
        for start, end in semester_starts:
            if start <= day_of_year <= end:
                return 'semester_start'
        for start, end in holiday_breaks:
            if start <= day_of_year <= end:
                return 'holiday_break'
        return 'normal'

    def generate_loan_fact_csv(self):
        print(f"📚 Generating {TARGET_VOLUMES['LOAN_FACT']:,} LOAN_FACT records (10-Year Span)...")
        data = []
        for i in range(TARGET_VOLUMES['LOAN_FACT']):
            date_key = random.choice(DIMENSION_RANGES['date_keys'])
            pattern = self.get_academic_pattern(date_key)
            
            # Apply multipliers based on academic pattern
            if pattern in ['study_period', 'exam_period']:
                duration = random.randint(7, 21)
                overdue = random.randint(0, 5) if random.random() < 0.3 else 0
            else:
                duration = random.randint(14, 30)
                overdue = random.randint(0, 10) if random.random() < 0.2 else 0

            data.append({
                'member_key': random.choice(DIMENSION_RANGES['member_keys']),
                'book_key': random.choice(DIMENSION_RANGES['book_keys']),
                'staff_key': random.choice(DIMENSION_RANGES['staff_keys']),
                'date_key': date_key,
                'loanID': f"L{(i % 99999):05d}",
                'loanDuration': duration,
                'overdueDays': overdue,
                'loanStatus': random.choice(['ACTIVE', 'RETURNED']),
                'totalFine': round(overdue * random.uniform(0.5, 2.0), 2),
                'fine_paid_flag': 1 if overdue > 0 and random.random() < 0.7 else 0
            })
            if (i + 1) % 25000 == 0: print(f"   ...generated {i + 1:,} loan records...")
        
        df = pd.DataFrame(data)
        df.to_csv('LOAN_FACT_data.csv', index=False)
        print(f"✅ Saved {len(data):,} LOAN_FACT records to LOAN_FACT_data.csv")

    def generate_sales_fact_csv(self):
        print(f"💰 Generating {TARGET_VOLUMES['SALES_FACT']:,} SALES_FACT records (10-Year Span)...")
        data = []
        for i in range(TARGET_VOLUMES['SALES_FACT']):
            date_key = random.choice(DIMENSION_RANGES['date_keys'])
            pattern = self.get_academic_pattern(date_key)
            
            if pattern == 'semester_start':
                qty = random.randint(1, 5)
                price = round(random.uniform(30, 80), 2)
            elif pattern in ['study_period', 'exam_period']:
                qty = random.randint(1, 3)
                price = round(random.uniform(15, 45), 2)
            else:
                qty = 1
                price = round(random.uniform(20, 50), 2)

            data.append({
                'date_key': date_key,
                'member_key': random.choice(DIMENSION_RANGES['member_keys']),
                'book_key': random.choice(DIMENSION_RANGES['book_keys']),
                'staff_key': random.choice(DIMENSION_RANGES['staff_keys']),
                'orderID': f"S{(i % 99999):05d}",
                'orderQty': qty,
                'orderUnitPrice': price,
                'orderTotalPrice': round(qty * price, 2)
            })
            if (i + 1) % 25000 == 0: print(f"   ...generated {i + 1:,} sales records...")

        df = pd.DataFrame(data)
        df.to_csv('SALES_FACT_data.csv', index=False)
        print(f"✅ Saved {len(data):,} SALES_FACT records to SALES_FACT_data.csv")

    def generate_purchase_fact_csv(self):
        print(f"📦 Generating {TARGET_VOLUMES['PURCHASE_FACT']:,} PURCHASE_FACT records (10-Year Span)...")
        data = []
        for i in range(TARGET_VOLUMES['PURCHASE_FACT']):
            date_key = random.choice(DIMENSION_RANGES['date_keys'])
            pattern = self.get_academic_pattern(date_key)
            
            if pattern in ['holiday_break', 'semester_start']:
                qty = random.randint(10, 40)
                cost = round(random.uniform(18, 35), 2)
            else:
                qty = random.randint(1, 10)
                cost = round(random.uniform(15, 30), 2)

            data.append({
                'date_key': date_key,
                'book_key': random.choice(DIMENSION_RANGES['book_keys']),
                'staff_key': random.choice(DIMENSION_RANGES['staff_keys']),
                'supplier_key': random.choice(DIMENSION_RANGES['supplier_keys']),
                'purchaseID': f"P{(i % 99999):05d}",
                'purchaseQuantity': qty,
                'purchaseUnitCost': cost,
                'purchaseTotalCost': round(qty * cost, 2)
            })
            if (i + 1) % 25000 == 0: print(f"   ...generated {i + 1:,} purchase records...")
            
        df = pd.DataFrame(data)
        df.to_csv('PURCHASE_FACT_data.csv', index=False)
        print(f"✅ Saved {len(data):,} PURCHASE_FACT records to PURCHASE_FACT_data.csv")

    def generate_reservation_fact_csv(self):
        print(f"📋 Generating {TARGET_VOLUMES['RESERVATION_FACT']:,} RESERVATION_FACT records (10-Year Span)...")
        data = []
        popular_books = random.sample(list(DIMENSION_RANGES['book_keys']), 500)
        
        for i in range(TARGET_VOLUMES['RESERVATION_FACT']):
            start_date_key = random.choice(DIMENSION_RANGES['date_keys'])
            # Ensure end_date_key does not exceed the maximum date_key
            end_date_key = min(start_date_key + 7, DIMENSION_RANGES['date_keys'].stop - 1)
            
            data.append({
                'member_key': random.choice(DIMENSION_RANGES['member_keys']),
                'book_key': random.choice(popular_books), # Reservations cluster on popular books
                'staff_key': random.choice(DIMENSION_RANGES['staff_keys']),
                'reserve_start_date_key': start_date_key,
                'reserve_end_date_key': end_date_key,
                'reserveID': f"R{(i % 99999):05d}",
                'reservationStatus': random.choice(['FULFILLED', 'EXPIRED', 'ACTIVE', 'CANCELLED']),
                'reservationDuration': end_date_key - start_date_key
            })
            if (i + 1) % 25000 == 0: print(f"   ...generated {i + 1:,} reservation records...")

        df = pd.DataFrame(data)
        df.to_csv('RESERVATION_FACT_data.csv', index=False)
        print(f"✅ Saved {len(data):,} RESERVATION_FACT records to RESERVATION_FACT_data.csv")

    def generate_all_csv_files(self):
        print("🎯 Library Data Warehouse - CSV Generator (10-Year Span)")
        print("=" * 50)
        self.generate_loan_fact_csv()
        self.generate_sales_fact_csv()
        self.generate_purchase_fact_csv()
        self.generate_reservation_fact_csv()
        print("=" * 50)
        print("🎉 All CSV files regenerated successfully with 10-year data span!")
        print("Next step: Truncate fact tables and reload using `load_csv_to_oracle.py`")

if __name__ == "__main__":
    generator = CSVDataGenerator()
    generator.generate_all_csv_files()
