"""
Library Data Warehouse - CSV Generator Only
Generates CSV files for bulk loading (no Oracle connection needed)
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

# Simulate dimension ranges (adjust based on your actual data)
DIMENSION_RANGES = {
    'date_keys': range(1, 3651),      # 10 years of dates
    'book_keys': range(1000, 11000),  # 10K books  
    'member_keys': range(1000, 11000), # 10K members
    'staff_keys': range(1000, 1022),   # 21 staff
    'supplier_keys': range(1000, 1011)  # 10 suppliers
}

# Academic calendar patterns (simplified)
ACADEMIC_PATTERNS = {
    'study_period': [15, 16, 17, 139, 140, 141, 142, 272, 273, 274, 275, 276, 277, 278],  # Study weeks
    'exam_period': [18, 19, 20, 21, 145, 146, 147, 148, 149, 279, 280, 281, 282, 283],   # Exam weeks  
    'semester_start': list(range(20, 35)) + list(range(244, 259)),  # Jan 20-Feb 4, Sep 1-16
    'holiday_break': list(range(160, 244)) + list(range(360, 366)),  # Summer + Winter break
    'normal': list(range(35, 139)) + list(range(259, 272)) + list(range(284, 360))  # Regular periods
}

class CSVDataGenerator:
    def __init__(self):
        self.fake = Faker()
        
    def generate_loan_fact_csv(self):
        """Generate LOAN_FACT CSV with academic patterns"""
        print(f"📚 Generating {TARGET_VOLUMES['LOAN_FACT']:,} LOAN_FACT records...")
        
        data = []
        id_counter = 100000
        
        for i in range(TARGET_VOLUMES['LOAN_FACT']):
            # Academic pattern weights
            pattern_weights = {
                'study_period': 0.3,
                'exam_period': 0.2, 
                'semester_start': 0.25,
                'normal': 0.2,
                'holiday_break': 0.05
            }
            
            pattern = random.choices(list(pattern_weights.keys()), 
                                   weights=list(pattern_weights.values()))[0]
            date_key = random.choice(ACADEMIC_PATTERNS[pattern])
            
            # Random dimension keys
            member_key = random.choice(DIMENSION_RANGES['member_keys'])
            book_key = random.choice(DIMENSION_RANGES['book_keys'])
            staff_key = random.choice(DIMENSION_RANGES['staff_keys'])
            
            loan_id = f"L{(id_counter % 99999):04d}"
            
            # Academic period affects loan characteristics
            if pattern in ['study_period', 'exam_period']:
                duration = random.randint(7, 21)  # Shorter during busy periods
                overdue = random.randint(0, 5) if random.random() < 0.3 else 0
            else:
                duration = random.randint(14, 30)  # Normal duration
                overdue = random.randint(0, 10) if random.random() < 0.2 else 0
            
            fine_amount = round(overdue * random.uniform(0.5, 2.0), 2) if overdue > 0 else 0
            fine_paid = 1 if fine_amount > 0 and random.random() < 0.7 else 0
            status = random.choice(['ACTIVE', 'RETURNED', 'OVERDUE'])
            
            data.append({
                'member_key': member_key,
                'book_key': book_key,
                'staff_key': staff_key,
                'date_key': date_key,
                'loanID': loan_id,
                'loanDuration': duration,
                'overdueDays': overdue,
                'loanStatus': status,
                'totalFine': fine_amount,
                'fine_paid_flag': fine_paid
            })
            
            id_counter += 1
            
            if (i + 1) % 10000 == 0:
                print(f"   Generated {i + 1:,} loan records...")
        
        # Save to CSV
        df = pd.DataFrame(data)
        df.to_csv('LOAN_FACT_data.csv', index=False)
        print(f"✅ Saved {len(data):,} LOAN_FACT records to LOAN_FACT_data.csv")
    
    def generate_sales_fact_csv(self):
        """Generate SALES_FACT CSV with textbook rush patterns"""
        print(f"💰 Generating {TARGET_VOLUMES['SALES_FACT']:,} SALES_FACT records...")
        
        data = []
        id_counter = 100000
        
        for i in range(TARGET_VOLUMES['SALES_FACT']):
            # Academic patterns affect sales
            pattern_weights = {
                'semester_start': 0.4,  # Heavy textbook buying
                'study_period': 0.2,
                'exam_period': 0.15,
                'normal': 0.2,
                'holiday_break': 0.05
            }
            
            pattern = random.choices(list(pattern_weights.keys()), 
                                   weights=list(pattern_weights.values()))[0]
            date_key = random.choice(ACADEMIC_PATTERNS[pattern])
            
            member_key = random.choice(DIMENSION_RANGES['member_keys'])
            book_key = random.choice(DIMENSION_RANGES['book_keys'])
            staff_key = random.choice(DIMENSION_RANGES['staff_keys'])
            order_id = f"S{(id_counter % 99999):04d}"
            
            # Pattern affects quantities and prices
            if pattern == 'semester_start':
                qty = random.randint(1, 5)  # Bulk textbook purchases
                price = round(random.uniform(30, 80), 2)  # Higher textbook prices
            elif pattern in ['study_period', 'exam_period']:
                qty = random.randint(1, 3)  # Study guides
                price = round(random.uniform(15, 45), 2)
            else:
                qty = 1
                price = round(random.uniform(20, 50), 2)
            
            total_price = round(qty * price, 2)
            
            data.append({
                'date_key': date_key,
                'member_key': member_key,
                'book_key': book_key,
                'staff_key': staff_key,
                'orderID': order_id,
                'orderQty': qty,
                'orderUnitPrice': price,
                'orderTotalPrice': total_price
            })
            
            id_counter += 1
            
            if (i + 1) % 10000 == 0:
                print(f"   Generated {i + 1:,} sales records...")
        
        df = pd.DataFrame(data)
        df.to_csv('SALES_FACT_data.csv', index=False)
        print(f"✅ Saved {len(data):,} SALES_FACT records to SALES_FACT_data.csv")
    
    def generate_purchase_fact_csv(self):
        """Generate PURCHASE_FACT CSV"""
        print(f"📦 Generating {TARGET_VOLUMES['PURCHASE_FACT']:,} PURCHASE_FACT records...")
        
        data = []
        id_counter = 100000
        
        for i in range(TARGET_VOLUMES['PURCHASE_FACT']):
            # Procurement patterns
            pattern_weights = {
                'holiday_break': 0.4,   # Semester prep
                'semester_start': 0.3,
                'normal': 0.2,
                'study_period': 0.05,
                'exam_period': 0.05
            }
            
            pattern = random.choices(list(pattern_weights.keys()), 
                                   weights=list(pattern_weights.values()))[0]
            date_key = random.choice(ACADEMIC_PATTERNS[pattern])
            
            book_key = random.choice(DIMENSION_RANGES['book_keys'])
            staff_key = random.choice(DIMENSION_RANGES['staff_keys'])
            supplier_key = random.choice(DIMENSION_RANGES['supplier_keys'])
            purchase_id = f"P{(id_counter % 99999):04d}"
            
            # Pattern affects purchase volumes
            if pattern == 'holiday_break':
                qty = random.randint(10, 40)  # Bulk semester prep
                cost = round(random.uniform(18, 35), 2)
            elif pattern == 'semester_start':
                qty = random.randint(5, 20)  # Emergency restocking
                cost = round(random.uniform(20, 40), 2)
            else:
                qty = random.randint(1, 10)
                cost = round(random.uniform(15, 30), 2)
            
            total_cost = round(qty * cost, 2)
            
            data.append({
                'date_key': date_key,
                'book_key': book_key,
                'staff_key': staff_key,
                'supplier_key': supplier_key,
                'purchaseID': purchase_id,
                'purchaseQuantity': qty,
                'purchaseUnitCost': cost,
                'purchaseTotalCost': total_cost
            })
            
            id_counter += 1
            
            if (i + 1) % 10000 == 0:
                print(f"   Generated {i + 1:,} purchase records...")
        
        df = pd.DataFrame(data)
        df.to_csv('PURCHASE_FACT_data.csv', index=False)
        print(f"✅ Saved {len(data):,} PURCHASE_FACT records to PURCHASE_FACT_data.csv")
    
    def generate_reservation_fact_csv(self):
        """Generate RESERVATION_FACT CSV with queue simulation"""
        print(f"📋 Generating {TARGET_VOLUMES['RESERVATION_FACT']:,} RESERVATION_FACT records...")
        
        data = []
        id_counter = 100000
        
        # Create queues for popular books
        popular_books = random.sample(list(DIMENSION_RANGES['book_keys']), 500)
        records_per_book = TARGET_VOLUMES['RESERVATION_FACT'] // len(popular_books)
        
        for book_key in popular_books:
            for queue_position in range(records_per_book):
                # Academic patterns
                pattern_weights = {
                    'semester_start': 0.4,
                    'study_period': 0.3,
                    'normal': 0.2,
                    'exam_period': 0.1
                }
                
                pattern = random.choices(list(pattern_weights.keys()), 
                                       weights=list(pattern_weights.values()))[0]
                start_date_key = random.choice(ACADEMIC_PATTERNS[pattern])
                end_date_key = start_date_key + 7  # 7-day policy
                
                member_key = random.choice(DIMENSION_RANGES['member_keys'])
                staff_key = random.choice(DIMENSION_RANGES['staff_keys'])
                reserve_id = f"R{(id_counter % 99999):04d}"
                
                # Queue position affects status
                if queue_position < 3:
                    status = 'FULFILLED'
                elif queue_position < 8:
                    status = 'EXPIRED'
                else:
                    status = random.choice(['ACTIVE', 'ACTIVE', 'CANCELLED'])
                
                data.append({
                    'member_key': member_key,
                    'book_key': book_key,
                    'staff_key': staff_key,
                    'reserve_start_date_key': start_date_key,
                    'reserve_end_date_key': end_date_key,
                    'reserveID': reserve_id,
                    'reservationStatus': status,
                    'reservationDuration': 7
                })
                
                id_counter += 1
        
        df = pd.DataFrame(data)
        df.to_csv('RESERVATION_FACT_data.csv', index=False)
        print(f"✅ Saved {len(data):,} RESERVATION_FACT records to RESERVATION_FACT_data.csv")
    
    def generate_all_csv_files(self):
        """Generate all CSV files"""
        print("🎯 Library Data Warehouse - CSV Generator")
        print("=" * 50)
        print("Generating CSV files for bulk loading...")
        print()
        
        self.generate_loan_fact_csv()
        print()
        self.generate_sales_fact_csv()
        print()
        self.generate_purchase_fact_csv()
        print()
        self.generate_reservation_fact_csv()
        print()
        
        print("=" * 50)
        print("🎉 All CSV files generated successfully!")
        print()
        print("Generated files:")
        for file in ['LOAN_FACT_data.csv', 'SALES_FACT_data.csv', 
                    'PURCHASE_FACT_data.csv', 'RESERVATION_FACT_data.csv']:
            if os.path.exists(file):
                size = os.path.getsize(file) / (1024*1024)  # MB
                print(f"   {file}: {size:.1f} MB")
        
        print()
        print("Next steps:")
        print("1. Run: load_csv_data.sql")
        print("2. Verify with: VOLUME_CHECK.sql")

if __name__ == "__main__":
    generator = CSVDataGenerator()
    generator.generate_all_csv_files()
