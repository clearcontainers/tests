# Copyright (c) 2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set up an Ubuntu image with 'blogbench' from the Phoronix testsuite installed

FROM ubuntu

RUN apt-get update && \
	apt-get install -y build-essential wget && \
	wget https://download.pureftpd.org/pub/blogbench/blogbench-1.1.tar.gz && \
	tar xvzf blogbench-1.1.tar.gz && \
	cd blogbench-1.1 && \
	./configure && \
	make && \
	make install-strip

CMD ["/bin/bash"]

# To run:
#  blogbench -d /tmp
