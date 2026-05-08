@echo off
title sea-aquaculture-tunnel-8797
echo [INFO] Starting SSH tunnel 8797 -> 127.0.0.1:8797
ssh -N -L 8797:127.0.0.1:8797 -J lijiyao@172.30.3.166 lijiyao@gpu6000
