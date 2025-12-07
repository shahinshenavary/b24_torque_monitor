# Excel Template Format

## Structure:

| Column A | Column B | Column C | Column D | Column E |
|----------|----------|----------|----------|----------|
| Project Name | Building A - Foundation | | | |
| Location | Tehran, District 2 | | | |
| | | | | |
| Pile ID | Pile Number | Pile Type | Expected Torque | Expected Depth |
| P-001 | 1 | Type A | 150 | 12.5 |
| P-002 | 2 | Type B | 160 | 13.0 |
| P-003 | 3 | Type A | 155 | 12.8 |

## Rules:
- **Row 1:** "Project Name" in A1, value in B1
- **Row 2:** "Location" in A2, value in B2  
- **Row 3:** Empty (separator)
- **Row 4:** Headers (Pile ID, Pile Number, Pile Type, Expected Torque, Expected Depth)
- **Row 5+:** Pile data

## Notes:
- DATA TAG and VIEW PIN are NOT in Excel - operator enters them manually
- If project info is missing in Excel, operator can enter manually
