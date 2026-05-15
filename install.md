                                                                                                                   
  ---                                                                                                              
  Étape 1 — Build & push l'image                                                                                   
                                                                                                                   
  cd "/Users/lesurmatthis/dev/projet perso/collega/collega_backend"                                                
                                                                                                                   
  # Build pour linux/amd64 (Unraid = x86)                                                                          
  docker build --platform linux/amd64 -t tistech0/collega-backend:latest .
                                                                                                                   
  # Push sur Docker Hub                                                                                          
  docker push tistech0/collega-backend:latest                                                                      
                                                                                                                 
  Étape 2 — Exporter ta DB locale                                                                                  
   
  # Dump de la base locale (le conteneur doit tourner)                                                             
  docker compose exec db pg_dump -U postgres --no-owner --no-acl collega > collega_dump.sql                        
                                                                                                                   
  Étape 3 — Sur le NAS (via SSH ou terminal Unraid)                                                                
                                                                                                                   
  # Créer les dossiers de données                                                                                  
  mkdir -p /mnt/user/appdata/collega/{postgres,redis,caddy/data,caddy/config,pdfs}                               
                                                                                                                   
  # Copier les fichiers depuis ton Mac (depuis ton Mac)                                                            
  scp collega_dump.sql root@IP_DU_NAS:/mnt/user/appdata/collega/                                                   
  scp docker-compose.prod.yml root@IP_DU_NAS:/mnt/user/appdata/collega/                                            
  scp Caddyfile.prod root@IP_DU_NAS:/mnt/user/appdata/collega/                                                     
                                                                                                                   
  # Créer le .env à partir de l'exemple (sur le NAS)                                                               
  cp .env.nas.example /mnt/user/appdata/collega/.env                                                               
  nano /mnt/user/appdata/collega/.env  # remplir les vraies valeurs                                                
                                                                                                                   
  Étape 4 — Lancer le stack sur Unraid
                                                                                                                   
  # Sur le NAS, dans le dossier du compose                                                                       
  cd /mnt/user/appdata/collega                                                                                     
   
  # 1. Démarrer seulement la DB                                                                                    
  docker compose -f docker-compose.prod.yml up -d db        
  sleep 10  # attendre que postgres soit prêt                                                                      
                                                                                                                   
  # 2. Importer le dump
  docker compose -f docker-compose.prod.yml exec -T db \                                                           
    psql -U postgres collega < collega_dump.sql                                                                    
   
  # 3. Lancer tout le reste                                                                                        
  docker compose -f docker-compose.prod.yml up -d           
                                                                                                                   
  ---                                                       
  Question clé pour le Caddyfile : ton testeur accède en local (même réseau que le NAS) ou depuis internet ? Si
  internet, tu as un domaine ou DDNS ? Si local uniquement, Caddy est optionnel et le testeur accède directement   
  sur http://IP_NAS:8000.
                                                                                                                   
✻ Cogitated for 2m 14s   
