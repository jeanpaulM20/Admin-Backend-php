# Eigene BRouter-Instanz (Routing für den Routenplaner, Rundtour, A→B,
# Assistent). Ersetzt die öffentliche Instanz brouter.de, die bei schnellen
# Anfragefolgen drosselt. Siehe README.md.
FROM eclipse-temurin:17-jre-jammy

ARG BROUTER_VERSION=1.7.10

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/brouter

# Offizielles Release: Server-Jar und Standardprofile (trekking, fastbike,
# gravel, mtb, hiking-mountain, …)
RUN curl -fsSL -o brouter.zip \
      "https://github.com/abrensch/brouter/releases/download/v${BROUTER_VERSION}/brouter-${BROUTER_VERSION}.zip" \
 && unzip -q brouter.zip \
 && mv "brouter-${BROUTER_VERSION}/brouter-${BROUTER_VERSION}-all.jar" brouter.jar \
 && mv "brouter-${BROUTER_VERSION}/profiles2" profiles2 \
 && rm -rf brouter.zip "brouter-${BROUTER_VERSION}" \
 && mkdir -p customprofiles /data/segments4

# „hiking-beta" (Wandern/Joggen im Backend) ist kein Standardprofil —
# Kopie von brouter.de, siehe profiles/README
COPY profiles/hiking-beta.brf profiles2/hiking-beta.brf
COPY start.sh ./start.sh
RUN chmod +x start.sh

# Kartendaten liegen unter /data — auf Railway als Volume eingehängt (eine
# VOLUME-Anweisung lehnt Railways Builder ab); ohne Volume werden sie bei
# jedem Start neu geladen
EXPOSE 17777
CMD ["/opt/brouter/start.sh"]
