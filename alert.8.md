# alert(8) — Tool to Send Messages to MS Teams Workflows

## NAME

**alert** — send messages to Microsoft Teams channels or workflows via Power Automate

## SYNOPSIS

`alert` [**-c** | **--config** _configuration-file_] [**-e** | **--environment** _environment_] [**-t** | **--title** _"TITLE line"_] [**-b** | **--body** _"body text"_] [**-f** | **--file** _file-for-body-text_] [**-i** | **--image** _"URL"_] [**-w** | **--webhook** _webhook-URL_] [**-h** | **--help**] [**-v** | **--version**]

## DESCRIPTION

**alert** is a command-line utility for sending messages to Microsoft Teams channels or workflows using Power Automate. It is designed for automation and scripting, enabling quick notifications or status updates from shell scripts or system tools.

The message body can be provided via:

- the `--body` argument (direct text input)
- the `--file` argument (read from a file or standard input)
- standard input (if `--file` is specified as `-` or omitted and input is piped)

## CONFIGURATION

The **alert** tool does *not* include a default configuration file. However, it is strongly recommended to create a configuration file for easier use.

### Configuration File Location

- **Linux:** `/etc/alert.conf` (default if not specified)
- **Windows:** `C:\Program Files\Common Files\Alert\alert.conf`

You can override the default location with the `--config` option.

### Configuration File Format

The configuration file supports two settings:

- `ENVIRONMENT=_environment_`  
  (Optional. Can also be detected from `/etc/tier` or via `/bin/ohai` Chef command if present.)
- `WEBHOOK_URL=_URL_`  
  (Required; must be a valid MS Teams Power Automate webhook URL.)

Example `/etc/alert.conf`

    ENVIRONMENT=sandbox
    WEBHOOK_URL=https://example.powerplatform.com/powerautomate/automations/direct/workflows/xyz/triggers/manual/paths/invoke

**ENVIRONMENT**  
Common values: `sandbox`, `development`, `qa`, `uat`, `production`, or any string you prefer.

**WEBHOOK_URL**  
Must be a valid URL for your MS Teams workflow. An invalid URL will result in HTTP errors, such as status code 405 "Method Not Allowed".

## OPTIONS

| Option                | Description                                                                               |
|-----------------------|-------------------------------------------------------------------------------------------|
| **-c**, **--config** *file*      | Specify configuration file (default: `/etc/alert.conf`)                               |
| **-e**, **--environment** *env*  | Specify environment (overrides config and auto-detection)                            |
| **-t**, **--title** *text*       | Title line for message (**required**)                                               |
| **-b**, **--body** *text*        | Body text (optional if `--file` is used)                                           |
| **-f**, **--file** *file*        | Read body text from file or stdin (required if `--body` is not used)                |
| **-i**, **--image** *url*        | URL for logo/image (optional)                                                      |
| **-w**, **--webhook** *url*      | Webhook URL (overrides config value)                                                |
| **-h**, **--help**               | Display usage information                                                           |
| **-v**, **--version**            | Display version information                                                         |

* **--config** *file*:
To overrurle the default configuration file `/etc/alert.conf`. However, it must contain at least a line like:

    WEBHOOK_URL=https://example.powerplatform.com/powerautomate/automations/direct/workflows/xyz/triggers/manual/paths/invoke

The `ENVIRONMENT` setting may still be retrieved from the `/etc/tier` file (if found), or via the Chef command `ohai`. If the
ENVIRONMENT is not found at all it will become the default setting `development`.

* **--environment** *env*:
To overrule the setting found in the configuration file. It can be any word as it is only used to be displayed in the header line in parentheses, e.g. `Alert on <hostname> (sandbox)`.

* **--title** *text*:
The text line is displayed as a bold line.

* **--body** *text*:
This is an one line text to display in the body section of the work flow message.

* **--file** *file*:
The body message can also be read from a file or from the standard input if both **--body** and **--title** arguments are missing on the command line. However, via the standard input there is a fixed time-out defined of 10 seconds to start entering your body text.

* **--image** *url*:
There is a default image defined (a black and white robot logo), however you may overrule it with another URL (only https:// is allowed). Keep in mind the maximum width is 279 pixels and the maximum height is 313 pixels of the image.

* **--webhook** *url*:
The URL (only https:// is allowed) of the MS Teams Power Automation channel.

* **--help**:
Shows the **alert** usage.

* **--version**:
Shows the **alert** version.
 
## EXAMPLES

**1. Error when required parameter is missing:**


    $ alert -e sbx -b "some text."
    Missing required --title argument.


**2. Sending a message with a body and title (using configuration file):**

    $ alert -e sbx -b "some text." -t "Title"

**3. Reading message body from a file, auto-detecting environment:**

    $ alert --file /etc/tier -t "TIER"

**4. Reading body from standard input:**

    $ cat /etc/hosts | alert -t "HOSTS"
    Reading body from stdin (timeout 10 seconds)...

## SEE ALSO

- Microsoft Teams documentation
- Power Automate documentation

## AUTHOR

Gratien D'haese <gdhaese1@its.jnj.com>
