# Seguridad-de-Redes

# Laboratorio de Seguridad de Redes - Segmentación y Control Perimetral

## Enlace del Video Demostrativo
> **Video:** [ENLACE_DE_YOUTUBE_O_ONEDRIVE_AQUI]  
> *(Demostración práctica mostrando rostro, fecha/hora y validación de políticas).*

---

## 1. Propósito del Laboratorio
Implementar una arquitectura perimetral y segmentación de red utilizando un firewall FortiGate y un switch L2. Se valida el control de tráfico entre zonas de usuarios (VLAN 10) y servidores DMZ (VLAN 20), la entrega dinámica de direccionamiento por DHCP, y la detección e intercepción en Capa 7 de ataques web mediante firmas de seguridad WAF.

---

## 2. Direccionamiento IP (Matrícula: 0846)

| Zona / Dispositivo | Interfaz | Red / IP | Función |
| :--- | :--- | :--- | :--- |
| **WAN** | port1 | Subred VMware | Salida a Internet y acceso GUI |
| **VLAN 10 (Usuarios)** | port2.10 | 10.8.46.1/25 | Gateway y DHCP (Rango .10 a .100) |
| **User 1** | eth0 | 10.8.46.10/25 | Host de usuario / pruebas |
| **VLAN 20 (DMZ)** | port2.20 | 10.8.46.129/28 | Gateway Servidores DMZ |
| **Web Server** | eth0 | 10.8.46.130/28 | Servidor HTTP / DVWA |
| **DB Server** | eth0 | 10.8.46.131/28 | Servidor MySQL (Puerto 3306) |

---

## 3. Resumen de Políticas y Seguridad Implementada

* **Switch L2:** Hardening básico (cifrado de claves, banner disuasivo, acceso protegido) y enlaces de acceso asignados a sus respectivas VLANs.
* **Política Salida Internet:** NAT activo para salida externa de usuarios y filtrado de descargas de ejecutables (.exe).
* **Política Acceso Web:** Permite tráfico HTTP desde usuarios hacia el Web Server (`10.8.46.130`).
* **Política Bloqueo DB:** Política explícita de rechazo (DENY) en el puerto TCP 3306 desde la red de usuarios hacia el DB Server (`10.8.46.131`).
* **Protección contra Inyección SQL:** Inspección de tráfico web mediante el motor WAF/IPS del FortiGate para mitigar ataques dirigidos a la base de datos a través de la aplicación.

---

## 4. Evidencias de Pruebas y Bloqueo

### A. Prueba de Acceso y Bloqueo de SQL Injection
Se ejecutó una solicitud HTTP conteniendo una carga maliciosa clásica (`' OR '1'='1`) hacia la aplicación web:

```bash
curl -v http://10.8.46.130/login.php?id=1'%20OR%20'1'='1
Resultado:
El firewall FortiGate interceptó la petición en Capa 7 reconociendo la firma de ataque, descartó la solicitud y devolvió al cliente un código de estado HTTP/1.1 403 Forbidden con la página oficial de bloqueo del Web Application Firewall (Event Type: signature).

---
