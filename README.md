# Epoxi

Epoxi is an Elixir OTP-based Mail Transfer Agent (MTA) and Mail Delivery Agent (MDA) designed for high-volume, fault-tolerant email delivery. It leverages the power of the Erlang OTP to provide a robust and scalable email handling solution.

## Project Architecture

Epoxi's architecture is designed for robustness and scalability, built around several core components:

### 1. Email Handling

*   `Epoxi.Email`: Represents an email message, including its content, headers, recipients, and delivery status. This struct is central to tracking the state of an email as it moves through the system.
*   `Epoxi.Render`: Responsible for encoding `Epoxi.Email` structs into the proper MIME format, ensuring that emails are correctly formatted for delivery according to internet standards.
*   `Epoxi.SmtpClient`: Handles the sending of emails to external SMTP servers. It utilizes the `gen_smtp` library for robust SMTP communication, managing connections, and handling server responses.
*   `Epoxi.SmtpServer`: Implements an SMTP server to receive incoming emails from other MTAs. This allows Epoxi to act as a primary or backup mail server.
*   `Epoxi.SmtpConfig`: Manages configuration settings for SMTP connections, including server addresses, ports, authentication credentials, and security options (e.g., TLS/SSL).

### 2. Queue Management

*   `Epoxi.Queue`: Implements a durable message queue using a combination of ETS (Erlang Term Storage) for fast in-memory operations and DETS (Disk Erlang Term Storage) for persistence. This hybrid approach ensures that emails are not lost in case of a system restart and can be processed efficiently.
*   `Epoxi.Queue.Processor`: A Broadway-based pipeline responsible for processing queued emails. It handles dequeuing messages, managing back-pressure, and coordinating the email sending process through `Epoxi.SmtpClient`.
*   `Epoxi.Queue.Producer`: Produces messages from the `Epoxi.Queue` for the `Epoxi.Queue.Processor` (Broadway pipeline), feeding emails into the processing workflow.

### 3. Web Interface

*   `Epoxi.Endpoint`: Provides an HTTP(S) endpoint using the Bandit web server. This allows for web-based interactions with Epoxi, such as viewing queue status, statistics, or managing configurations.
*   `Epoxi.Router`: Routes incoming HTTP requests from the `Epoxi.Endpoint` to the appropriate handlers, enabling different web functionalities.

### 4. Telemetry

*   `Epoxi.Telemetry`: Collects and reports metrics related to email processing, queue status, system performance, and other vital signs. This data can be used for monitoring, alerting, and capacity planning.

### 5. Distributed Architecture

*   `Epoxi.Cluster`: Contains helper functions and utilities for managing clustering and distribution of Epoxi nodes. This enables Epoxi to run in a multi-node setup for high availability and load balancing.
*   `Epoxi.Node`: Manages node-specific operations and facilitates distributed tasks across the cluster, ensuring cohesive operation in a distributed environment.

## Installation

Epoxi is currently under active development. To get started with the project, you can follow these general steps for Elixir applications:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/epoxi.git # Replace with the actual repository URL
    cd epoxi
    ```

2.  **Install dependencies:**
    Epoxi uses Mix to manage dependencies. Fetch and install them by running:
    ```bash
    mix deps.get
    ```

3.  **Compile the project:**
    Compile the application and its dependencies:
    ```bash
    mix compile
    ```

Further setup instructions will be added as the project matures.

## Usage

To run the Epoxi application locally:

```bash
mix run --no-halt
```
This command starts the OTP application, including all supervised processes like the SMTP server and queue processors.

For specific configuration options (e.g., SMTP ports, database connections for DETS, clustering settings), please refer to the configuration files in the `config/` directory (`config/config.exs`, `config/dev.exs`, etc.). Detailed configuration guides will be provided as development progresses.

## Contributing

Contributions to Epoxi are welcome! If you'd like to contribute, please follow these steps:

1.  **Fork the repository** on GitHub.
2.  **Create a new branch** for your feature or bug fix:
    ```bash
    git checkout -b your-feature-name
    ```
3.  **Make your changes** and commit them with clear, descriptive messages.
4.  **Ensure your code adheres to the existing style** and that all tests pass (if applicable).
5.  **Push your branch** to your forked repository:
    ```bash
    git push origin your-feature-name
    ```
6.  **Submit a pull request** to the main Epoxi repository.

Please ensure your pull request describes the problem you're solving or the feature you're adding. If it's a significant change, it's often best to open an issue first to discuss the proposed changes.

## License

Epoxi is released under the MIT License. See the `LICENSE` file for more details.

