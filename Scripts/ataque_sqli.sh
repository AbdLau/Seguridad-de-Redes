#!/bin/bash
# Script de prueba para deteccion y bloqueo de SQL Injection
echo "Enviando payload de SQL Injection al Web Server..."
curl -v "http://10.8.46.130/login.php?id=1'%20OR%20'1'='1"