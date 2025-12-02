1) Given number of minutes, convert it into human readable form. 
Example : 
130 becomes “2 hrs 10 minutes” 
110 becomes “1hr 50minutes” 

Source Code:

def convert_minutes(total_minutes):
    hours = total_minutes // 60
    minutes = total_minutes % 60
    
     
    h_label = "hr" if hours == 1 else "hrs"
    m_label = "minute" if minutes == 1 else "minutes"
    
    return f"{hours} {h_label} {minutes} {m_label}"


num=int(input())
print(convert_minutes(num))
