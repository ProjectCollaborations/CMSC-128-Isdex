# isdex

## Logical View Diagram
![System Architecture Diagram](system-architecture.png)

## Flow Description
**1. Auth Service** monitors the authentication state and checks log-in status of the User.

**2. Auth Service** concurrently **feeds log-in data** (such as the User UID and User Object) **directly to the Screens** to manage access control.

**3.** The **User** triggers an event by interacting with a specific Screen (e.g., adding a new fish sighting).

**4.** The **Screen directly updates the Firebase DB** by pushing new data to a specific node (e.g., user_sightings_temp).

**5.** The **Firebase DB** utilizes a persistent connection to **feed real-time data** updates back to the **Screens**.

**6.** The **Screen listens to this stream**, processes the raw data into **Marker** objects, and refreshes the map display for the user.