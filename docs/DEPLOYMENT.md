# Deployment

## Remote backend

Remote project root:

`/share/home/lijiyao/CCCC/sea-aquaculture-agent`

Default backend port:

`8797`

Start backend:

```bash
bash deploy/server_start_tmux.sh
```

Stop backend:

```bash
bash deploy/server_stop_tmux.sh
```

Read logs:

```bash
bash deploy/server_logs.sh
```

## Sync local files to server

```bash
bash deploy/sync_to_server.sh
```

## Local SSH tunnel

```bash
bash deploy/local_tunnel.sh
```

## Local frontend

```bash
bash deploy/local_start_frontend.sh
```

Windows alternatives:

```powershell
.\deploy\local_start_frontend.ps1
```

or

```cmd
deploy\local_start_frontend.cmd
```

The backend is not intended to be started locally. Frontend development should always connect to the server backend through the tunnel.
