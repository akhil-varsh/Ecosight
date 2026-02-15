# EcoSight: Send Google Maps Link via Twilio SMS

from twilio.rest import Client

# Twilio credentials (replace with your actual values or import from config)
TWILIO_SID = "AC08854d517d4c0ba1775cec4e96b47fa0"
TWILIO_AUTH_TOKEN = "0e27c4d019e48f41931c467856e569b8"
TWILIO_FROM = "+18723501845"
GUARDIAN_PHONE_NUMBER = "+918523072687"

latitude = 17.537459740503298
longitude = 78.3854384918926

maps_url = f"https://maps.google.com/?q={latitude},{longitude}"
message_body = f"EcoSight Alert:\nUser location: {maps_url}"

client = Client(TWILIO_SID, TWILIO_AUTH_TOKEN)

try:
    message = client.messages.create(
        body=message_body,
        from_=TWILIO_FROM,
        to=GUARDIAN_PHONE_NUMBER
    )
    print(f"SMS sent! SID: {message.sid}")
    print(f"Message: {message_body}")
except Exception as e:
    print(f"Failed to send SMS: {e}")
