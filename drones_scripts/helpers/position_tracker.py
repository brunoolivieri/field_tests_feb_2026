import csv

class PositionTracker:
    def __init__(self):
        self.data = []

    def track_position(self, time, position):
        """Add a new row to the dataframe with the given time and position."""
        self.data.append({'simulation_time': time, 'position': position})
    
    def save_to_csv(self, filename):
        """Save the data to a CSV file."""
        with open(filename, 'w', newline='') as csvfile:
            fieldnames = ['simulation_time', 'position']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(self.data)