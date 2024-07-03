if __name__ == "__main__":
    # Open the forecasts CSV file and read in the lines
    with open("forecasts.csv", "r") as file:
        forecasts = file.readlines()

    # Initialize variables
    old_value = 1
    new_list = []

    # Process each line in the forecasts
    for f in forecasts[1:]:
        # Remove any quotes and whitespace
        strpf = f.replace('"', '').strip()
        
        # Split the string to get the date and forecast value
        parts = strpf.split(',')
        
        # Construct the new string with the lagged forecast value
        new_str = f"{parts[0]},{old_value}\n"
        
        # Update old_value to the current forecast value for the next iteration
        old_value = parts[1]
        
        # Append the new string to the list
        new_list.append(new_str)

    # Write the new data to forecasts_new.csv
    with open("forecasts_new.csv", "w") as out_file:
        for n in new_list:
            out_file.write(n)