Mailtest
=

Mailtest is a bash script for testing your SMTP and IMAP server is working correctly. An alert via Pushover will be send when the test fails. 

My setup
--
I have a Postfix and Dovecot server running on a VPS. The script is running on my Raspberry Pi at home by a Cron job:

``
0 11 * * * "/root/scripts/mailtest.sh" >> /var/log/mailtest.log
``

What the script does
--
1. The script sends an email to my Gmail account
2. A Gmail rule based on the subject and sender, sends the message back
3. The script checks every 5 seconds or the email is received
4. If the script timed out there will be send a Pushover message to my mobile device.