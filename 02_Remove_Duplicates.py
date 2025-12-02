2) You are given a string, remove all the duplicates and print the unique string.Use loop in the python.

Source Code:

s = input("Enter a string: ")

unique = ""
for ch in s:
    if ch not in unique:
        unique += ch

print("Unique string:", unique)