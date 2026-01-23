#*******************************************************************************
#AUTHOR:Lorenzo Primiterra
 #COURSE: COMP3649
 #INSTRUCTOR: Marc 
 #DATE: January 22, 2026

# FILE: Starter_Code.py

# SUMMARY: Contains Functions that handle:
# Opening of file, reading and extracting each line.
# A token function that removes unwanted delimiters and preps the exracted line for checks.
# Boolean Check function #1 that determines if the line starts or ends with an operator and throws the determined exception.
# Boolean Check function #2 that determines if the line contains operator duplicates and throws the determined exception.

#*************************************
#*************************************


import re

#*******************************************************************************
#    PURPOSE: The 'Main' of the program (not modularized right now)
#    INPUT:   - N/A
#    OUTPUT:  - N/A
#*******************************************************************************
def main():
    filename = "test.txt"
    open_file(filename)
    

#*******************************************************************************
#    PURPOSE: Opens the file and extracting each line and providing Error Handling.
#    INPUT:   The filename 
#    OUTPUT:  calls token Extracter to begin 'cleaning' and checking each line.
#*******************************************************************************
def open_file(filename):
    try:
        with open(filename, "r") as f:
            line_num = 1
            for line in f:
                if not line.strip():
                    continue  # Skip empty lines
                token_extractor(line, filename, line_num)
                line_num += 1

    except FileNotFoundError:
        print(f"Error: The file '{filename}' was not found.")



#*******************************************************************************
#    PURPOSE: Removes [,\s;\n]+ delimiters from each line while also checking to make 
#               sure that the line checked is not empty. 
#    INPUT:   The unprocessed line from the open function, the file name, and a counter that determines which line is currently being processed.
#    OUTPUT:  A processed array of tokens that are ready to be gramatically checked.
#*******************************************************************************
def token_extractor(untokenized_line, filename, line_num):
    delimiters = r"[,\s;\n]+"
    tokenized_line = re.split(delimiters, untokenized_line.strip())  # Removes delimiters/spaces and if they are next to eachother.
    
    # Remove empty strings
    cleaned_tokens = []
    for t in tokenized_line:
        if t:  # If t is not empty
            cleaned_tokens.append(t)
    tokenized_line = cleaned_tokens
    start_n_end_checker(tokenized_line, filename, line_num)
    duplicate_operators_checker(tokenized_line, filename, line_num)


#*******************************************************************************
#    PURPOSE: This function checks whether the tokenized line begins or ends with an operator which would be invalid 
#    INPUT:   the tokenized array, the filename and the line number.
#    OUTPUT:  A boolean that determines whether the line is valid or not and will through an error if it isn't.
#*******************************************************************************
def start_n_end_checker(tokenized_line, filename, line_num):
    valid_operators = ["+", "=", "-", "/", "*"]
    
    # Check if the first token is an operator
    first_token = tokenized_line[0]
    if first_token in valid_operators:
        print(f"Error in '{filename}' line {line_num}: starts with '{first_token}'")
        return None
    
    # Check if the last token is an operator
    last_token = tokenized_line[-1]  # -1 gets the last element
    if last_token in valid_operators:
        print(f"Error in '{filename}' line {line_num}: ends with '{last_token}'")
        return None

    
    return True

#*******************************************************************************
#    PURPOSE: This checker determines whether or not their are duplicate operators within the current line.
#    INPUT:   the tokenized array (line), the filename and the line number.
#    OUTPUT:  A boolean to whether the above is true or false
#*******************************************************************************
def duplicate_operators_checker(tokenized_line, filename, line_num):
    valid_operators = ["+", "=", "-", "/", "*"]
    
    # Loop through tokens, checking each one against the next
    for i in range(len(tokenized_line) - 1):
        current_token = tokenized_line[i]
        next_token = tokenized_line[i + 1]
        
        # If current token is an operator AND next token is also an operator
        if current_token in valid_operators and next_token in valid_operators:
            print(f"Error in '{filename}' line {line_num}: duplicate operators '{current_token}' '{next_token}'")
            return False
    
    return True
                





if __name__ == "__main__":
    main()
