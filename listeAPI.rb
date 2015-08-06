# #!/usr/bin/env ruby
# # ©2015 Jean-Hugues Roy. GNU GPL v3.

require "json"
require "open-uri"
require "csv"
require "google/api_client"
require "google_drive"
require "twitter"

# Lecture, au préalable, et chargement dans la variable «circs» d'un CSV contenant des informations qui ne changent pas:
# - les codes de circonscription;
# - leurs noms dans les deux langues officielles;
# - les noms des provinces et territoires (en ingles y frances tambien);
# - la population

circs = CSV.read("circonscriptions.csv", :headers => true).to_a

# Fonction pour convertir les noms de partis de l'anglais au français, si nécessaire

def par(p)
	case p
	when "Conservative"
		parti = "Parti conservateur"
	when "Liberal"
		parti = "Parti libéral"
	when "NDP"
		parti = "NPD"
	when "Green Party"
		parti = "Parti vert"
	when "Libertarian"
		parti = "Parti libertarien"
	else parti = p
	end
	return parti
end

# Initialisation de quelques variables

circonscription = ""
riding = ""
provinceFr = ""
provinceEng = ""
population = ""
n = 0

# Initialisation de notre tableau «contenant» avec les entêtes de colonnes qu'on va placer dans Google Sheets

tous = [["Prénom/First name","Nom de famille/Last name","Nom/Name","Genre/Gender","Sortant?","Incumbent?","Parti","Party","Code","Circonscription","Riding","Province (F)","Province (E)","Population","Courriel/E-mail","Twitter","Facebook","Instagram","Page perso/Personal site","Photo"]]

# Boucle qui fait appel à l'API Represent le moins souvent possible (en chargeant le maximum de 1000 candidats à la fois)

(0..3000).step(1000) {|page|

	requete = "https://represent.opennorth.ca/candidates/house-of-commons/?limit=1000&offset=#{page}"
	
	# Analyse du texte JSON retourné par l'API
	
	puts requete
	r = open(requete)
	donnees = JSON.parse(r.read)
	
	# Les candidats sont contenus dans l'objet «objects»
	
	candidats = donnees["objects"]
	
	# Chaque candidat est lui-même un objet contenant divers éléments qu'il suffit d'extraire
	
	candidats.each do |candidat|
		n += 1
		c = []
		c.push candidat["first_name"]
		c.push candidat["last_name"]
		c.push candidat["name"]
		c.push candidat["gender"]
		if candidat["incumbent"] == true
			sortant = "Oui"
			incumbent = "Yes"
		else
			sortant = "Non"
			incumbent = "No"
		end
		c.push sortant
		c.push incumbent
		party = candidat["party_name"]
		parti = par(party)
		c.push parti
		c.push party
		rel = candidat["related"]
		if rel["boundary_url"] != nil
			code = rel["boundary_url"][-6..-2]
			# Ici, on extrait le code de circonscription et on s'en sert pour l'associer aux infos contenues dans le CSV qu'on a chargé au départ, comme ça, on s'assure de l'uniformité dans les noms de circonscriptions et de provinces
			circs.each do |circ|
				if circ[0] == code
					circonscription = circ[1]
					riding = circ[3]
					provinceFr = circ[2]
					provinceEng = circ[4]
					population = circ[5]
				end
			end
		end
		c.push code
		c.push circonscription
		c.push riding
		c.push provinceFr
		c.push provinceEng
		c.push population
		c.push candidat["email"]
		social = candidat["extra"]
		c.push social["twitter"]
		c.push social["facebook"]
		c.push social["instagram"]
		c.push candidat["personal_url"]
		c.push candidat["photo_url"]

		tous.push c
		
		puts "Le candidat #{nom} est dans #{circonscription} (#{code}), province: #{provinceFr}" # Affichage pour vérifier
	end
}

puts "On a #{n} candidats." # Un autre affichage de vérification

# Construction du texte de l'heure à laquelle on a mis à jour la liste

date = Time.new
d = date.to_a
a = date.year
mo = date.strftime("%m")
j = date.strftime("%d")
h = date.hour
mi = date.min

t = "#{a}#{mo}#{j}-#{h}h#{mi}"

# Connexion à l'API de Google pour lire et écrire dans la Google Sheet; remplacez les noms de Pokémon par vos informations personnelles

id = "Pikachu"
codeSecret = "Bulbasaur"
refreshToken = "Jigglypuff"

client = Google::APIClient.new(
  :application_name => 'Mewtwo',
  :application_version => '1.0.0'
)

auth = client.authorization
auth.client_id = id
auth.client_secret = codeSecret
auth.scope =
    "https://docs.google.com/feeds/ " +
    "https://docs.googleusercontent.com/ " +
    "https://spreadsheets.google.com/feeds/"

auth.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
auth.refresh_token = refreshToken
auth.refresh!
access_token = auth.access_token
session = GoogleDrive.login_with_oauth(access_token)

ws = session.spreadsheet_by_key("Poliwag").worksheets[0]

nbCandidats = ws.num_rows-2

puts "Le tableau comptait #{nbCandidats} candidats; l'API en contient #{n}."

# Écriture de tout ce que l'API vient de nous donner dans la Google Sheet

tous.each_with_index do |ligne,i|
	ligne.each_with_index do |item,x|
		puts "Sur la ligne #{i+1}, colonne #{x+1}, on met la valeur #{ligne[x]}"
		ws[i+1,x+1] = ligne[x]
	end
end

# Écriture d'uen dernière ligne avec quelques infos, notamment la date et l'heure de la dernière extraction

ws.title=("Candidat(e)s - Date: #{t}")
ws[n+2,1] = "Dernière mise à jour - Last updated:"
ws[n+2,2] = "#{t}"
ws[n+2,3] = "Source: REPRESENT, par/by Nord Ouvert/Open North (https://represent.opennorth.ca/)"
ws.save()
ws.reload()

urlListe = "https://goo.gl/M9pz3j"

# Si le nombre de candidats que vient de nous donner l'API est supérieur au nombre de candidats qu'il y avait déjà dans la Google Sheet, on envoie des tweets dans les deux langues officielles

if n > nbCandidats
	
	# Connexion à l'API de Twitter pour tweeter; remplacez les personnages de la Ribouldingue avec vos infos

	twit = Twitter::REST::Client.new do |config|
	  config.consumer_key        = "Mandibule"
	  config.consumer_secret     = "Bedondaine"
	  config.access_token        = "Paillasson"
	  config.access_token_secret = "Dame Plume"
	end
	
	# French Tweet

	tweetF = "#fed2015\n
	#{n} candidats jusqu'à maintenant\n
	#{urlListe}\n
	Liste mise à jour à tt les h grâce à l'API Represent, de @nordouvert\n
	#polcan"
	puts tweetF
	twit.update(tweetF)
	
	sleep(60)
	
	# Tweet en anglais
	
	tweetA = "#{n} candidates running in #elxn42 up to now\n
	#{urlListe}\n
	List updated thanks to @opennorth's awesome Represent API\n
	#canpoli"
	puts tweetA
	twit.update(tweetA)

end
