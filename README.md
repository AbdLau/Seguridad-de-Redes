# Seguridad-de-Redes

# Laboratorio de Seguridad de Redes #2

## Enlace del Video Demostrativo
> **Video:** [ENLACE_DE_YOUTUBE_O_ONEDRIVE_AQUI]  
> *(Demostración práctica mostrando rostro, fecha/hora y validación de políticas).*

---

## 1. Propósito del Laboratorio
El propósito fundamental de este laboratorio es diseñar, desplegar y validar una arquitectura de red empresarial segmentada y protegida bajo el principio de defensa en profundidad (Defense in Depth), empleando un firewall de próxima generación (FortiGate) como núcleo de control perimetral e inspección de tráfico, integrado con un switch Cisco de Capa 2 para el aislamiento de dominios de difusión.

Los objetivos específicos de seguridad comprenden:

- Segmentación de Red: Aislar rigurosamente a los usuarios corporativos de los servicios críticos de backend mediante el despliegue de VLANs y subinterfaces 802.1Q.
- Control de Acceso de Menor Privilegio: Restringir el tráfico inter-VLAN permitiendo únicamente los flujos y servicios autorizados (HTTP/HTTPS y MySQL).
- Inspección Profunda de Aplicaciones (Layer 7): Analizar el tráfico hacia el servidor web mediante firmas de seguridad de aplicaciones web (WAF / IPS) para interceptar ataques dirigidos como Inyección SQL (SQLi).
- Mitigación de Amenazas de Ejecución: Restringir el tráfico saliente a Internet evitando la descarga o propagación de archivos ejecutables (.exe).
- Resiliencia ante Denegación de Servicio: Implementar políticas de control de tasa (Rate Limiting) en Capa 4 contra inundaciones TCP/SYN y anomalías volumétricas.
- Hardening en Capa de Acceso: Mitigar vulnerabilidades de Capa 2 en el switch de distribución mediante Port Security, control de enlaces troncales y deshabilitación de interfaces en desuso.

---

## 2. Direccionamiento IP (Matrícula: 0846)

En conformidad con las instrucciones de la práctica, se diseñó el esquema de subredes utilizando el bloque privado principal derivado de los dígitos de matrícula **0846** (`10.8.46.0/24`), segmentado con longitud de máscara variable (VLSM):

### Tabla General de Direccionamiento

| Dispositivo / Interfaz | Zona / VLAN | Dirección IP / Prefijo | Puerta de Enlace | Modo de Asignación | Rol en la Red |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **FortiGate - port1** | WAN / External | Dinámica (Subred VMware) | Asignado por ISP/VMware | DHCP Client | Salida a Internet y acceso GUI |
| **FortiGate - port2.10** | VLAN 10 (Usuarios) | `10.8.46.1/25` | N/A | Estática | Gateway de Usuarios y DHCP Server |
| **FortiGate - port2.20** | VLAN 20 (Servidores) | `10.8.46.129/28` | N/A | Estática | Gateway de Servidores DMZ |
| **User 1 (eth0)** | VLAN 10 (Usuarios) | `10.8.46.10/25` | `10.8.46.1` | DHCP Client | Estación de trabajo y pruebas |
| **WEB Server (eth0)** | VLAN 20 (Servidores) | `10.8.46.130/28` | `10.8.46.129` | Estática | Servidor Web Apache / HTTP / HTTPS |
| **DB Server (eth0)** | VLAN 20 (Servidores) | `10.8.46.131/28` | `10.8.46.129` | Estática | Servidor Base de Datos MySQL |

### Subredes Utilizadas

| Subred | Máscara Decimal | Rango de Hosts Válidos | Gateway | Capacidad | Propósito |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `10.8.46.0/25` | `255.255.255.128` | `10.8.46.1` – `10.8.46.126` | `10.8.46.1` | 126 hosts | Red de Usuarios (VLAN 10) |
| `10.8.46.128/28` | `255.255.255.240` | `10.8.46.129` – `10.8.46.142` | `10.8.46.129` | 14 hosts | DMZ Servidores (VLAN 20) |


---


## 3. Topología de Red

La infraestructura fue desplegada en el simulador GNS3, utilizando la máquina virtual de FortiGate conectada mediante troncal 802.1Q al switch Cisco, distribuyendo los puertos hacia las zonas de red requeridas.

```text
               +---------------------------+
               |    Cloud1 (VMware NAT)    |
               +---------------------------+
                             |
                   port1 (WAN / DHCP NAT)
                             |
               +---------------------------+
               |       FortiGate NGFW      |
               |     (Admin GUI / NAT)     |
               +---------------------------+
                             |
                     port2 (802.1Q Trunk)
                             |
               +---------------------------+
               |      Switch Cisco L2      |
               +---------------------------+
                 /           |           \
     Gi0/1 (VLAN 10)   Gi0/2 (VLAN 20)   Gi0/3 (VLAN 20)
               /             |             \
   +---------------+ +---------------+ +---------------+
   |    User 1     | |   WEB Server  | |   DB Server   |
   | (VLAN 10 /25) | | (VLAN 20 /28) | | (VLAN 20 /28) |
   |  Cliente/Test | |  HTTP / HTTPS | |  MySQL (3306) |
   +---------------+ +---------------+ +---------------+

```

### Componentes de la Topología:

- FortiGate NGFW (VM64-KVM): Actúa como pasarela por defecto (Gateway) de todas las VLANs, proveedor del servicio DHCP para usuarios, enrutador NAT hacia Internet y motor de inspección de seguridad perimetral.
- Switch Cisco L2: Proporciona conmutación de Capa 2, división lógica de VLANs, encapsulación dot1q en el troncal y control de acceso físico mediante Port Security.
- User 1 (Nodo Cliente): Equipo ubicado en VLAN 10 con direccionamiento dinámico asignado por el FortiGate, utilizado para validar acceso a servicios, navegación y pruebas de inyección.
- WEB Server: Servidor ubicado en la DMZ (VLAN 20) que aloja aplicaciones web seguras y servicios HTTP/HTTPS para interacción con usuarios.
- DB Server: Servidor de base de datos MySQL (puerto TCP 3306) ubicado en la DMZ (VLAN 20), aislado del acceso directo de clientes externos.
- Cloud1: Adaptador de red conectado al stack de virtualización de VMware para acceso a Internet vía NAT y administración remota de la GUI de FortiOS desde el host físico.


---


## 4. Arquitectura y Funcionamiento del Tráfico
1. **Red de Usuarios (VLAN 10):**
   * Los clientes se conectan a puertos de acceso en el switch asignados a la VLAN 10.
   * El FortiGate entrega automáticamente la dirección IP, máscara de subred (`/25`), gateway predeterminado (`10.8.46.1`) y servidores DNS vía DHCP.
   * El acceso a recursos internos y externos está condicionado a las políticas de inspección del firewall.
2. **Red de Servidores (VLAN 20 - DMZ):**
   * Los servidores operan bajo una subred reducida (`/28`), con asignación estática para garantizar consistencia en la aplicación de objetos y políticas de seguridad.
   * El gateway asignado en los servidores es la subinterfaz `10.8.46.129`.
3. **Enrutamiento y Control de Tráfico en FortiGate:**
   * **Usuarios → Servidor Web:** Tráfico permitido únicamente hacia el puerto web (HTTP/HTTPS) del servidor `10.8.46.130`, sujeto a inspección profunda de Capa 7.
   * **Usuarios → Base de Datos:** Tráfico dirigido al puerto TCP 3306 de `10.8.46.131` es descartado explícitamente mediante una regla de bloqueo (`DENY`), registrando los eventos en los logs del firewall.
   * **Servidor Web → Servidor Base de Datos:** Comunicación permitida estrictamente hacia el puerto TCP 3306 (MySQL) sin NAT, asegurando que la base de datos reconozca la IP real del servidor web solicitante. Cualquier otro puerto entre ambos servidores es bloqueado.
4. **Salida a Internet y Traducción NAT:**
   * La interfaz física `port1` opera conectada a la red NAT de VMware, obteniendo salida dinámica a Internet y ruta por defecto `0.0.0.0/0`.
   * El firewall realiza Source NAT (SNAT) sobre el tráfico de las subredes internas hacia el exterior y aplica filtrado de archivos para bloquear ejecutables.


---


## 5. Configuraciones Implementadas

### A. Switch Cisco L2 (Hardening y Segmentación)
* **Hardening del Dispositivo:** Deshabilitación de búsqueda de nombres de dominio (`no ip domain-lookup`), cifrado de contraseñas de texto plano en memoria (`service password-encryption`), establecimiento de clave secreta administrativa (`enable secret`) y despliegue de banner disuasorio legal (MOTD).
* **Segmentación L2:** Creación formal de la base de datos de VLANs con identificadores `10` (USUARIOS) y `20` (SERVIDORES).
* **Troncal 802.1Q:** Configuración del puerto hacia el firewall en modo troncal (`switchport mode trunk`) con encapsulación dot1q y desactivación de negociación DTP (`switchport nonegotiate`).
* **Seguridad de Puertos (Port Security):** En los puertos de acceso hacia clientes y servidores, se fijó el aprendizaje persistente de direcciones físicas (`switchport port-security mac-address sticky`), se estableció un límite máximo de 2 direcciones MAC por interfaz y el modo de penalización ante intrusiones en `shutdown` o `restrict`.
* **Protección Spanning-Tree:** Habilitación de `spanning-tree portfast` y `bpduguard enable` en los puertos de acceso para evitar bucles accidentales o inyección de switches no autorizados.
* **Higiene de Puertos:** Desactivación administrativa (`shutdown`) de todas las interfaces no conectadas.


### B. Firewall FortiGate (Configuración 100% GUI)
* **Creación de Subinterfaces VLAN:** Dentro de **Network > Interfaces**, se crearon sobre `port2` las subinterfaces lógicas `VLAN10_USERS` (ID 10) y `VLAN20_SERVERS` (ID 20) asignando las IPs `10.8.46.1/25` y `10.8.46.129/28`.
* **Servidor DHCP:** Habilitado sobre `VLAN10_USERS` con un rango de entrega comprendido entre `10.8.46.10` y `10.8.46.100`.
* **Objetos de Dirección de Red:** En **Policy & Objects > Addresses**, se crearon los objetos dedicados `WEB-SERVER` (`10.8.46.130/32`) y `DB-SERVER` (`10.8.46.131/32`).
* **Inspección Profunda SSL (DPI):** En **Security Profiles > SSL/SSH Inspection**, se configuró el perfil `custom-deep-inspection` en modo *Full SSL Inspection*, ajustando los parámetros para permitir inspección sobre certificados del entorno de pruebas.
* **Firmas de Seguridad Web (WAF / IPS):** Despliegue de perfil de seguridad con firmas contra ataques de inyección SQL (`HTTP.URI.SQL.Injection`), configurado para descartar paquetes (*Block/Drop*) y registrar el evento.
* **Filtrado de Archivos (File Filter):** Creación del perfil `BLOCK-EXE-DOWNLOADS` con regla dirigida a interceptar tráfico HTTP entrante para extensiones `.exe` y ejecutables de Windows, aplicando acción de bloqueo inmediato.
* **Protección contra Denegación de Servicio (DoS Policy):** En **Policy & Objects > IPv4 DoS Policy**, se configuró una regla para la interfaz `VLAN10_USERS` monitoreando la anomalía de capa 4 `tcp_syn_flood`, con limitación de umbral de conexiones y acción de descarte.


---


## 6. Políticas de Seguridad y Perfiles UTM

Las reglas de firewall fueron ordenadas estrictamente de arriba hacia abajo para garantizar que las restricciones se evalúen antes de las políticas permisivas:

### Matriz de Políticas de Firewall

| ID / Nombre | Interfaz Origen | Interfaz Destino | Origen | Destino | Servicio | Acción | NAT | Perfiles / UTM Activos | Propósito |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **01: BLOQUEO-DB** | `VLAN10_USERS` | `VLAN20_SERVERS` | `all` | `DB-SERVER` | `MYSQL` (3306) | **DENY** | Desactivado | N/A (Log All Sessions) | Impedir acceso directo de usuarios a la base de datos. |
| **02: USERS-A-WEB** | `VLAN10_USERS` | `VLAN20_SERVERS` | `all` | `WEB-SERVER` | `HTTP`, `HTTPS` | **ACCEPT** | Desactivado | DPI + WAF/IPS (SQLi) | Acceso de usuarios a la app web con inspección de Capa 7. |
| **03: WEB-A-DB** | `VLAN20_SERVERS` | `VLAN20_SERVERS` | `WEB-SERVER` | `DB-SERVER` | `MYSQL` (3306) | **ACCEPT** | Desactivado | Log All Sessions | Permitir comunicación estricta entre servidores backend. |
| **04: INTERNET-NAT** | `VLAN10_USERS` | `port1` (WAN) | `all` | `all` | `ALL` | **ACCEPT** | **Habilitado** | File Filter (`.exe`) | Salida de clientes a Internet con bloqueo de descargas ejecutables. |
| **DoS: DOS-LIMIT** | `VLAN10_USERS` | N/A (L4 Anomaly) | `all` | `WEB-SERVER` | `TCP/HTTP` | **BLOCK** | N/A | Umbral SYN Flood | Mitigar ataques de denegación de servicio por saturación. |


---


## 7. Validación, Pruebas y Resultados

### Resumen de Pruebas Ejecutadas

| Prueba | Descripción del Procedimiento | Resultado Obtenido | Estado |
| :--- | :--- | :--- | :---: |
| **1. Asignación DHCP** | `User 1` solicita configuración de red en VLAN 10. | Obtiene `10.8.46.10/25`, Gateway `10.8.46.1` y resuelve red. | **Exitoso** |
| **2. Conectividad a Gateway** | `ping -c 3 10.8.46.1` desde `User 1`. | Respuesta inmediata sin pérdida de paquetes (0% packet loss). | **Exitoso** |
| **3. Acceso a Web Server** | Petición HTTP/HTTPS desde `User 1` hacia `10.8.46.130`. | Conexión establecida y respuesta con código HTTP 200 OK. | **Exitoso** |
| **4. Bloqueo hacia DB Server** | Intento de conexión con `nc -w 2 10.8.46.131 3306` desde `User 1`. | Conexión denegada por timeout tras 2 segundos. Política DENY aplicada. | **Exitoso** |
| **5. Comunicación Web → DB** | Verificación de puerto 3306 desde `10.8.46.130` hacia `10.8.46.131`. | Conexión establecida con éxito hacia el socket de MySQL. | **Exitoso** |
| **6. Salida a Internet y NAT** | `ping -c 3 8.8.8.8` desde `User 1`. | Conectividad saliente operativa a través de traducción NAT. | **Exitoso** |
| **7. Bloqueo de Descargas .exe** | Intento de descarga de un binario con `wget http://.../archivo.exe`. | Conexión terminada por el firewall. Descarga bloqueada por File Filter. | **Exitoso** |
| **8. Inyección SQL (Layer 7)** | Envío de carga maliciosa `' OR '1'='1` mediante solicitud web. | Firewall descarta la petición y devuelve respuesta **HTTP 403 Forbidden**. | **Exitoso** |
| **9. Registro del Ataque SQLi** | Consulta de logs en GUI de FortiGate tras el ataque. | Evento registrado en WAF / Security Events con firma e IP origen. | **Fallido** |
| **10. Rate Limiting / DoS** | Generación de ráfagas concurrentes de tráfico TCP SYN hacia el servidor. | Umbral superado; FortiGate incrementa contadores y descarta paquetes. | **Exitoso** |


> **Nota sobre las imágenes:** Todas las capturas de pantalla referentes a la evidencia del cumplimiento de esta práctica se encuentran debidamente organizadas y disponibles para su consulta directa dentro de la carpeta **`images/`** en el repositorio.
