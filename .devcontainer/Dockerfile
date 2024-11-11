FROM ghcr.io/browserless/chromium

# Get latest Flutter
USER root
RUN mkdir -p /usr/bin/flutter
RUN chown blessuser:blessuser /usr/bin/flutter -R

USER blessuser
RUN git clone -v -b stable https://github.com/flutter/flutter /usr/bin/flutter
RUN chmod +x /usr/bin/flutter/bin/flutter
ENV PATH="/usr/bin/flutter/bin:${PATH}"

# Disable telemetry
RUN flutter --disable-analytics

# Install flutter bash completion
RUN mkdir ~/.bash-completion -p
RUN flutter bash-completion > ~/.bash-completion/flutter
RUN chmod +x ~/.bash-completion/flutter

# Source flutter bash completion
RUN echo 'source ~/.bash-completion/flutter' >> ~/.bashrc