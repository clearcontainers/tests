/*
// Copyright (c) 2016 Intel Corporation
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
*/

package main

const caCertServer = `
-----BEGIN CERTIFICATE-----
MIIDIDCCAgigAwIBAgIQHCbqsGp9YYEs/WqDOYb1MzANBgkqhkiG9w0BAQsFADAQ
MQ4wDAYDVQQKEwVJbnRlbDAeFw0xNjA1MjcxNTI2NDhaFw0xNzA1MjcxNTI2NDha
MBAxDjAMBgNVBAoTBUludGVsMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEAsnWBUvBIqZEojr/+MkXMc8SSeQzKnNKo2mvMxuYZ1oBMoUkNTuxa+rHbFcsk
lDVaUtOh7edNOgtGa7pnJKT96iGJpHtRIYxSjP/YH7Kjcq6P2pNWft0mWn0vzCVU
Z58UtuoMyt5yV/D/1fGQOq+pbJMOOLxf3mHO2sJ63CzMMJfUN6ptn8siJ6tNPhFF
pQH33XNbIbXPjqHuFZ7X0KIjt/8RZWYNj700BLU0uvdTMefJKMtsmZmrFW86uHb2
RxumKoLRPJgAwzzrRUfNEfOJxKW7hZQtBA4uuCwYXh3LikpTNdCLkm7rrTLIKMbN
EaPZfIOQCw7IKGemQSt9lxWaCQIDAQABo3YwdDAOBgNVHQ8BAf8EBAMCAqQwGgYD
VR0lBBMwEQYEVR0lAAYJKwYBBAGCVwgCMA8GA1UdEwEB/wQFMAMBAf8wNQYDVR0R
BC4wLIIJbG9jYWxob3N0gR9jaWFvLWRldmVsQGxpc3RzLmNsZWFybGludXgub3Jn
MA0GCSqGSIb3DQEBCwUAA4IBAQAxUcFBi4ZKL4gNdlobG/1G341OTD+cVl/WTfhx
bXf7hMf3dHUekwgvqC+EWrAuYFqh3UaPIgpw+uJivXV9fjLzUFjFDLyBRaH9LEo4
Ohd+pRiIWNJ4wecWxZbyPkZtf8MonJTkhZF+6Zvlgdhd9dCPGVmPZOSHl2ZpaLeI
JiZ/Eg95U57qYMZOPSGDzRnzMHk57xc0oNH4EuSzmdojG5L82PtzOnRSpsEpEzpl
nyltsOhVvThnmWCgWA3L9a3glgShsBAM6wBRLzVuYsDNw/lUcmFsvWWi9U26U9O6
t+YtraOkFmqaU/PdBC+l5cEIHG2X2BzljC/EIBDx572i5t/k
-----END CERTIFICATE-----`

const certServer = `
-----BEGIN CERTIFICATE-----
MIIDIDCCAgigAwIBAgIQHCbqsGp9YYEs/WqDOYb1MzANBgkqhkiG9w0BAQsFADAQ
MQ4wDAYDVQQKEwVJbnRlbDAeFw0xNjA1MjcxNTI2NDhaFw0xNzA1MjcxNTI2NDha
MBAxDjAMBgNVBAoTBUludGVsMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEAsnWBUvBIqZEojr/+MkXMc8SSeQzKnNKo2mvMxuYZ1oBMoUkNTuxa+rHbFcsk
lDVaUtOh7edNOgtGa7pnJKT96iGJpHtRIYxSjP/YH7Kjcq6P2pNWft0mWn0vzCVU
Z58UtuoMyt5yV/D/1fGQOq+pbJMOOLxf3mHO2sJ63CzMMJfUN6ptn8siJ6tNPhFF
pQH33XNbIbXPjqHuFZ7X0KIjt/8RZWYNj700BLU0uvdTMefJKMtsmZmrFW86uHb2
RxumKoLRPJgAwzzrRUfNEfOJxKW7hZQtBA4uuCwYXh3LikpTNdCLkm7rrTLIKMbN
EaPZfIOQCw7IKGemQSt9lxWaCQIDAQABo3YwdDAOBgNVHQ8BAf8EBAMCAqQwGgYD
VR0lBBMwEQYEVR0lAAYJKwYBBAGCVwgCMA8GA1UdEwEB/wQFMAMBAf8wNQYDVR0R
BC4wLIIJbG9jYWxob3N0gR9jaWFvLWRldmVsQGxpc3RzLmNsZWFybGludXgub3Jn
MA0GCSqGSIb3DQEBCwUAA4IBAQAxUcFBi4ZKL4gNdlobG/1G341OTD+cVl/WTfhx
bXf7hMf3dHUekwgvqC+EWrAuYFqh3UaPIgpw+uJivXV9fjLzUFjFDLyBRaH9LEo4
Ohd+pRiIWNJ4wecWxZbyPkZtf8MonJTkhZF+6Zvlgdhd9dCPGVmPZOSHl2ZpaLeI
JiZ/Eg95U57qYMZOPSGDzRnzMHk57xc0oNH4EuSzmdojG5L82PtzOnRSpsEpEzpl
nyltsOhVvThnmWCgWA3L9a3glgShsBAM6wBRLzVuYsDNw/lUcmFsvWWi9U26U9O6
t+YtraOkFmqaU/PdBC+l5cEIHG2X2BzljC/EIBDx572i5t/k
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAsnWBUvBIqZEojr/+MkXMc8SSeQzKnNKo2mvMxuYZ1oBMoUkN
Tuxa+rHbFcsklDVaUtOh7edNOgtGa7pnJKT96iGJpHtRIYxSjP/YH7Kjcq6P2pNW
ft0mWn0vzCVUZ58UtuoMyt5yV/D/1fGQOq+pbJMOOLxf3mHO2sJ63CzMMJfUN6pt
n8siJ6tNPhFFpQH33XNbIbXPjqHuFZ7X0KIjt/8RZWYNj700BLU0uvdTMefJKMts
mZmrFW86uHb2RxumKoLRPJgAwzzrRUfNEfOJxKW7hZQtBA4uuCwYXh3LikpTNdCL
km7rrTLIKMbNEaPZfIOQCw7IKGemQSt9lxWaCQIDAQABAoIBAQCJEw7ByQTXEkNn
2nsC3HAdYBjt1/BtIrZGB1VkVWv1QdkabYVGYO/E7gYNKFsxaAW35wzTMr4z3mM5
7hS5pe3O//G8oGgB78mcuguk1U8MkJ64UkG28mE6Ujv7f5TkfuGnWgF3dgO4Hsoz
5/dTzIfDePUMiUzOAKylhYpfQh2ZGE2qak7LioXP2D1l7ZErVEEYGZrSiRXG1RoS
XLptAHOiJegYV9UTZmQY+t4t0C4NZmcLYhfq+ltw7giW6cZwBPkiS/U9MiCO3WCo
AuVa03s+S9AvEGdPWxqu2qs9Cq8v+xwDjIRQXPQ0j45XkQX1RKHXcg1ncwyDUOEN
L5epzI2NAoGBANKesNFFCzYhbsvIPnTJUcRFlFY/Fm+hawsGOoay96qSzwpYqPcO
khoij9LW+R2e4L/vGTuL5qa85SXXSh3xsSKJpFwjCbWx8XwM9OwfKmOG235gsVVB
ViRDmjGGX87o4qaveI0IE3X4ZlHgrgN0RHD7stnwJzv9NhKQJTkWRQzTAoGBANjo
5OV4Q7I4cLpI9Y9EAWJ29Y76DAPdJl1VgcdCTCtQO9mige+jzGLG/+vwTFLUEFsE
UqSxWuH94J03ssfWV5MttPeO0ivBjIgTeKRUlMSmv/AvfyEN6piGT7+yJTDzt7rv
DUibSR0JnwyAjztTUxNE/BOLPHnVZNOxQ+uM5EQzAoGAVi1GDaohZzmQuuKo42II
CbWqdwuDI5O5V55pzflmKq289u/F2qhkkTr4+/ynmz4JmZ68BUg9zJVXcP9AvTXK
E2acEHLpoyU2uFoY0JAD6QshvfjUNhzwoQ/kBEWF6AQT0L3VJmdahxdmzjOPH6yv
4EasLE39z6bQPBIsmMoK4K8CgYAkAa0Vhnw+Vm4oDjptGM3eCX9Dx7A85/YZYjtT
12aLfhshSn+lRxyDfSM4iEAzM66vXS1W13YNs7YYgwlzcNpCvUCgI54x00Q/xnOt
W7kCV+feuBOzafr6bLlKSgkwchSavFoJJnXhkxpK2gBsya0tsrLhj6hvVQQSvAdZ
T58IzwKBgBPe9XjQGfzThi+FZx9UjuMXJZ0gGGKC4Z9szMyn0L9UORqzr1fvmI51
6d16Hy27kCzQ7y1xWNXJKZyj6hHqN85QE/0inxnDX1/p5WLoDPvnRFOJLH++d3os
KPBrMl+4G4ZIuLdespl47h0pgwdlRO9Ri245oj0OStjPvMH7A/vC
-----END RSA PRIVATE KEY-----`
