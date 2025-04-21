defmodule Epoxi.TestSmtpErrorCodes do
  @moduledoc """
  A comprehensive collection of SMTP error codes and their descriptions.
  Includes both standard SMTP error codes and vendor-specific ones.
  """

  @doc """
  Returns a map of all SMTP error codes with their descriptions and messages.
  """
  def all do
    %{
      # 2xx Success Codes
      "211" => %{
        description: "System status message",
        message: "211 System status, or system help reply"
      },
      "214" => %{description: "Help message", message: "214 Help message"},
      "220" => %{description: "Service ready", message: "220 Service ready"},
      "221" => %{
        description: "Service closing",
        message: "221 Service closing transmission channel"
      },
      "250" => %{
        description: "Requested action completed",
        message: "250 Requested mail action okay, completed"
      },
      "251" => %{
        description: "User not local, forwarded",
        message: "251 User not local; will forward"
      },
      "252" => %{
        description: "Cannot VRFY, will attempt",
        message: "252 Cannot VRFY user, but will accept message and attempt delivery"
      },

      # 3xx Intermediate Codes
      "334" => %{description: "AUTH input", message: "334 Server challenge"},
      "350" => %{
        description: "Requested action pending",
        message: "350 Requested mail action pending further information"
      },
      "354" => %{
        description: "Start mail input",
        message: "354 Start mail input; end with <CRLF>.<CRLF>"
      },

      # 4xx Temporary Failure Codes
      "421" => %{
        description: "Service not available",
        message: "421 Service not available, closing transmission channel"
      },
      "422" => %{
        description: "Mailbox full",
        message: "422 The recipient's mailbox has exceeded its storage limit"
      },
      "431" => %{description: "Not enough space on disk", message: "431 Not enough space on disk"},
      "432" => %{
        description: "Processing error",
        message: "432 The recipient's Exchange Server incoming mail queue has been stopped"
      },
      "440" => %{
        description: "Connection timeout",
        message: "440 Connection timed out during transmission"
      },
      "441" => %{
        description: "The recipient's server is not responding",
        message: "441 The recipient's server is not responding"
      },
      "442" => %{
        description: "Connection dropped",
        message: "442 The connection was dropped during transmission"
      },
      "446" => %{
        description: "Maximum hop count exceeded",
        message: "446 The maximum hop count was exceeded for the message"
      },
      "447" => %{
        description: "Delivery time-out",
        message: "447 Your outgoing message timed out due to delivery time constraints"
      },
      "449" => %{description: "Routing error", message: "449 A routing error"},
      "450" => %{
        description: "Mailbox unavailable",
        message: "450 Requested mail action not taken: mailbox unavailable"
      },
      "451" => %{
        description: "Local error in processing",
        message: "451 Requested action aborted: local error in processing"
      },
      "452" => %{
        description: "Insufficient system storage",
        message: "452 Requested action not taken: insufficient system storage"
      },
      "471" => %{
        description: "Message content rejected",
        message: "471 An error of your mail server, often due to spam blocking"
      },

      # 5xx Permanent Failure Codes
      "500" => %{description: "Syntax error", message: "500 Syntax error, command unrecognized"},
      "501" => %{
        description: "Syntax error in parameters",
        message: "501 Syntax error in parameters or arguments"
      },
      "502" => %{description: "Command not implemented", message: "502 Command not implemented"},
      "503" => %{description: "Bad sequence of commands", message: "503 Bad sequence of commands"},
      "504" => %{
        description: "Command parameter not implemented",
        message: "504 Command parameter not implemented"
      },
      "510" => %{description: "Bad email address", message: "510 Bad email address"},
      "511" => %{description: "Bad email address", message: "511 Bad email address"},
      "512" => %{
        description: "DNS error",
        message: "512 Host server for the recipient's domain name cannot be found"
      },
      "513" => %{
        description: "Address type is incorrect",
        message: "513 Address type is incorrect"
      },
      "523" => %{
        description: "Size exceeds administrative limit",
        message: "523 The total size of your mailing exceeds the recipient server's limits"
      },
      "530" => %{description: "Authentication required", message: "530 Authentication required"},
      "535" => %{
        description: "Authentication credentials invalid",
        message: "535 Authentication failed: Bad username or password"
      },
      "541" => %{
        description: "Recipient address rejected",
        message: "541 The recipient address rejected your message"
      },
      "550" => %{
        description: "Mailbox unavailable",
        message: "550 Requested action not taken: mailbox unavailable"
      },
      "551" => %{
        description: "User not local",
        message: "551 User not local; please try forwarding"
      },
      "552" => %{
        description: "Exceeded storage allocation",
        message: "552 Requested mail action aborted: exceeded storage allocation"
      },
      "553" => %{
        description: "Mailbox name not allowed",
        message: "553 Requested action not taken: mailbox name not allowed"
      },
      "554" => %{description: "Transaction failed", message: "554 Transaction failed"},
      "555" => %{
        description: "MAIL/RCPT parameters not recognized",
        message: "555 MAIL FROM/RCPT TO parameters not recognized or not implemented"
      },
      "556" => %{
        description: "Domain does not accept mail",
        message: "556 Domain does not accept mail"
      },
      "557" => %{
        description: "Too many duplicate messages",
        message: "557 Too many duplicate messages, try again later"
      },
      "571" => %{
        description: "Blocked for spam",
        message: "571 Message contains spam or virus or sender is blocked"
      },
      "999" => %{description: "Generic error", message: "999 Internal server error or timeout"},

      # Google/Gmail Specific Codes
      "g421" => %{
        description: "Gmail temporary defer",
        message: "421 4.7.0 Try again later, closing connection"
      },
      "g450" => %{
        description: "Gmail greylist",
        message:
          "450 4.2.1 The user you are trying to contact is receiving mail at a rate that prevents additional messages from being delivered"
      },
      "g550_1" => %{
        description: "Gmail policy violation",
        message:
          "550 5.7.1 Our system has detected that this message is likely unsolicited mail. To reduce the amount of spam, this message has been blocked"
      },
      "g550_28" => %{
        description: "Gmail DMARC failure",
        message:
          "550 5.7.28 Email not accepted for policy reasons. Please review the DMARC authentication results"
      },
      "g550_26" => %{
        description: "Gmail domain reputation issue",
        message:
          "550 5.7.26 This message does not have authentication information or fails to pass authentication checks"
      },
      "g550_spam" => %{
        description: "Gmail spam detection",
        message:
          "550 5.7.1 [xxx.xxx.xxx.xxx] The user or domain that you are sending to has a policy that prohibited the mail that you sent"
      },

      # Microsoft/Outlook/Hotmail Specific Codes
      "m550_1" => %{
        description: "Microsoft unauthorized relay",
        message: "550 5.7.1 Unable to relay for user@domain.com"
      },
      "m550_4_1" => %{
        description: "Microsoft recipient not found",
        message: "550 5.4.1 Recipient address rejected: Access denied"
      },
      "m550_ou" => %{
        description: "Microsoft reputation issue",
        message:
          "550 OU-001 (SNT004-MC1F43) Unfortunately, messages from [xxx.xxx.xxx.xxx] weren't sent"
      },
      "m550_sc1" => %{
        description: "Microsoft spam content",
        message: "550 SC-001 Mail rejected by Outlook.com for policy reasons"
      },
      "m550_sc4" => %{
        description: "Microsoft phishing detection",
        message: "550 SC-004 Mail rejected by Outlook.com for policy reasons: Contains phishing"
      },
      "m550_dy" => %{
        description: "Microsoft domain reputation",
        message: "550 DY-001 Mail rejected by Outlook.com for policy reasons"
      },

      # Yahoo Specific Codes
      "y421" => %{
        description: "Yahoo temporary deferral",
        message:
          "421 4.7.0 [TSS04] Messages from x.x.x.x temporarily deferred due to user complaints"
      },
      "y554" => %{
        description: "Yahoo account not found",
        message: "554 delivery error: dd This user doesn't have a yahoo.com account"
      },
      "y554_spam" => %{
        description: "Yahoo spam detection",
        message: "554 Message not allowed - [299] Message content not accepted for policy reasons"
      },

      # AOL Specific Codes
      "a550_1" => %{
        description: "AOL address does not exist",
        message: "550 5.1.1 <email>... Requested address does not exist"
      },
      "a521" => %{
        description: "AOL mail rejection",
        message: "521 5.2.1 : AOL will not accept delivery of this message"
      },
      "a554" => %{description: "AOL spam rejection", message: "554 5.7.1 Spam/Virus detected"},

      # Other Vendor-Specific
      "v451_grey" => %{
        description: "Generic greylisting",
        message: "451 4.7.1 Please try again later"
      },
      "v550_spf" => %{description: "SPF failure", message: "550 5.7.23 SPF validation failed"},
      "v550_dkim" => %{
        description: "DKIM failure",
        message: "550 5.7.20 Message failed DKIM verification"
      },
      "v550_dmrc" => %{
        description: "DMARC failure",
        message: "550 5.7.1 Email rejected per DMARC policy"
      },
      "v550_bl" => %{
        description: "IP Blacklisted",
        message: "550 5.7.1 Service unavailable; Client host [x.x.x.x] blocked using blocklist"
      }
    }
  end

  @doc """
  Get an error by its error code.
  Returns the error map or nil if the code doesn't exist.
  """
  def get(code) when is_binary(code) do
    all()[code]
  end

  @doc """
  Check if a code exists in our error database.
  """
  def exists?(code) when is_binary(code) do
    Map.has_key?(all(), code)
  end
end
