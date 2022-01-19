
ARG PYTHON_VERSION_COMPAT=3.8
ARG WORKSPACE=/workspace
ARG APP_PATH=/app
ARG BUILD_ENV=/build/venv

FROM mcr.microsoft.com/azure-functions/python:3.0-python$PYTHON_VERSION_COMPAT-buildenv AS build
ARG PYTHON_VERSION_COMPAT
ARG WORKSPACE
ARG APP_PATH
ARG BUILD_ENV

WORKDIR $WORKSPACE
RUN set -ex \
    && apt-get update -yqq \
    && apt-get install -yqq --no-install-recommends \
    virtualenv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN virtualenv -p python$PYTHON_VERSION_COMPAT --system-site-packages $APP_PATH

RUN virtualenv -p python$PYTHON_VERSION_COMPAT --system-site-packages $BUILD_ENV \
    && . $BUILD_ENV/bin/activate \
    && pip install -U --no-cache pip poetry

COPY pyproject.toml poetry.lock .
RUN . $BUILD_ENV/bin/activate && \
    poetry export \
    -o requirements.txt \
    --without-hashes 

RUN . $APP_PATH/bin/activate && pip install --no-cache -r requirements.txt

FROM mcr.microsoft.com/azure-functions/python:3.0-python$PYTHON_VERSION_COMPAT as app
ARG PYTHON_VERSION_COMPAT
ARG WORKSPACE
ARG APP_PATH
ARG BUILD_ENV


COPY --from=build $APP_PATH $APP_PATH

# must be copied here: https://github.com/Azure/azure-functions-core-tools/issues/2496
COPY . /home/site/wwwroot

# this is required because AzureML https://stackoverflow.com/questions/67806547/ssl-error-accessing-azure-datastore-for-azure-auto-ml/70393819#70393819
ENV CLR_OPENSSL_VERSION_OVERRIDE=1.1 \
    AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true

ENV PATH=$APP_PATH/bin:$PATH
ENV VIRTUAL_ENV=$APP_PATH

CMD ["/azure-functions-host/Microsoft.Azure.WebJobs.Script.WebHost"]
