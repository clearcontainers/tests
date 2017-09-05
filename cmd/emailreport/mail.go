/// Copyright (c) 2017 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"log"
	"net/smtp"
	"strings"
)

// HeaderRFC822 provides a header as a
// string according the RFC822 Standard for ARPA
// Internet Text Messages.
func HeaderRFC822(conf Configuration, status string) string {
	var header string

	if conf.Mail.From == "" {
		log.Fatal("Sender not specified")
	}

	if conf.Mail.Subject == "" {
		log.Fatal("Message subject not specified")
	}

	if len(conf.Mail.To) == 0 {
		log.Fatal("Receipts not specified")
	}

	header += "From: " + conf.Mail.From + "\n"
	header += "To: " + strings.Join(conf.Mail.To, ",") + "\n"

	if len(conf.Mail.Cc) > 0 {
		header += "cc: " + strings.Join(conf.Mail.Cc, ",") + "\n"
	}

	header += "Subject: " + conf.Mail.Subject + " status: " + status + "\n\n"

	return header
}

// SendByEmail allows to send the result output of
// checkmetrics execution to a whitelist of emails.
// This list is described by a TOML configuration file.
func SendByEmail(conf Configuration, body string, status string) {
	var header string
	var msg string
	var auth smtp.Auth
	var server string

	header = HeaderRFC822(conf, status)
	msg = header + body

	auth = smtp.PlainAuth(
		conf.Mail.ID,       // SMTP identity
		conf.Mail.User,     // SMTP user
		conf.Mail.Password, // SMTP Server password
		conf.Mail.SMTP,     // SMTP server address
	)

	server = conf.Mail.SMTP + ":" + conf.Mail.Port

	// Connection/Authentication step
	err := smtp.SendMail(
		server,         // SMTP server:port
		auth,           // SMTP authentication
		conf.Mail.From, // Sender
		conf.Mail.To,   // Receipts
		[]byte(msg),    // Message
	)
	if err != nil {
		log.Fatal(err)
	}
}
