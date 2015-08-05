# #!/usr/bin/env ruby
# # ©2015 Jean-Hugues Roy. GNU GPL v3.

require "nokogiri"
require "open-uri"
require "net/http"
require "watir-webdriver"
require "csv"
require "rubygems"
require "typhoeus"

# Définition des URL des pages où se trouvent les candidats des différents partis

urlNPD = "http://www.npd.ca/candidats"
urlLib = "https://www.liberal.ca/fr/candidats/"
urlCon = "http://www.conservateur.ca/equipe/"
urlVerts = "http://www.greenparty.ca/fr/riding/2013-"
urlBloc = "http://www.blocquebecois.org/equipe-2015/candidats/"
urlFD = "http://www.forcesetdemocratie.org/l-equipe/candidats.html"

# Création d'un tableau («array») qui va contenir chacun de nos candidats
candidats = []

# Extraction des candidats du NPD; je vais mettre des commentaires uniquement lorsque c'est pertinent

tNPD1 = Time.new # On «punche» pour connaître l'heure exacte avant de commencer
puts "On commence à #{tNPD1}" # Heure qu'on affiche ici

# On commence par ouvrir la page des candidats du parti, tout en prenant soin de s'identifier

pageNPD = Nokogiri::HTML(open(urlNPD, "User-Agent" => "Jean-Hugues Roy, UQAM (roy.jean-hugues@uqam.ca)"))

# Boucle qui passe dans chacun des éléments contenant les infos d'un candidat

pageNPD.css("div.candidate-holder").each do |candidatNPD|
	candidat = {}
	candidat["Parti"] = "NPD"
	candidatNPD.css("a.candidate-donate").map do |lien|
		code = lien["href"]
		candidat["Code"] = code[code.index("don/")+4..-1]
	end
	candidat["Circonscription"] = candidatNPD.css("span.candidate-riding-name").text.strip
	candidat["Province"] = candidatNPD.css("span.candidate-prov-name").text.strip
	candidat["Nom"] = candidatNPD.css("div.candidate-name").text.strip
	if candidatNPD.css("a.candidate-twitter") != nil # parfois, il n'y a pas de balise avec l'information qu'on recherche; si on n'effectue pas cette vérification, notre script crashe
		candidatNPD.css("a.candidate-twitter").map do |lien|
			candidat["Twitter"] = lien["href"]
		end
	end
	puts candidat # Affichage des infos relatives au candidat qu'on vient de scraper, aux fins de vérification
	candidats.push candidat # On met notre hash «candidat» dans le tableau «candidats»
end

tNPD2 = Time.new # on «punche» à la sortie
puts "On termine à #{tNPD2}"

##################################################
# Extraction des candidats libéraux
##################################################

tLib1 = Time.new
puts "On commence à #{tLib1}"

pageLib = Nokogiri::HTML(open(urlLib, "User-Agent" => "Jean-Hugues Roy, UQAM (roy.jean-hugues@uqam.ca)"))

# Extraction des codes de circonscription, bien circonscrits dans le site libéral

codeCirc = []
pageLib.css("li.candidate-type-candidate").map do |id|
	codeCirc.push id["data-riding-riding_id"]
end

pageLib.css("li.candidate-type-candidate").each_with_index do |candidatLib,i|
	candidat = {}
	candidat["Parti"] = "Parti libéral"
	candidat["Code"] = codeCirc[i]
	candidat["Circonscription"] = candidatLib.css("h3.riding").text.strip
	candidat["Province"] = candidatLib.css("div.hidden.province").text.strip
	candidat["Nom"] = candidatLib.css("h2.name").text.strip
	if candidatLib.css("div.social") != nil
		candidat["Twitter"] = candidatLib.css("a")[0]["href"]
	end
	puts candidat
	candidats.push candidat
end

tLib2 = Time.new
puts "On termine à #{tLib2}"

##################################################
# Extraction des candidats conservateurs
##################################################

tCon1 = Time.new
puts "On commence à #{tCon1}"

# Démarrage d'un webdriver, nécessaire sur le site du Parti conservateur

cons = Watir::Browser.new
cons.goto urlCon

# Le webdriver clique virtuellement sur un lien et attend que tous les candidats se chargent sur la page

lien = cons.link :text => "Candidats"
lien.click
cons.div(:id => "candidates-yt").wait_until_present

# Une fois que tous les candidats sont dans la page, on les capture dans la variable liste

liste = cons.div(:id => "candidates")

# Variable qu'on analyse ensuite avec Nokogiri

pageCon = Nokogiri::HTML::Document.parse(liste.html)
pageCon.css("a").map { |u|
	url1 = u["data-learn"] # On construit la fin de l'URL de la page du candidat à partir de l'info trouvée dans l'élément intitulé «data-learn»
	urlCon2 = urlCon + url1 # On finit de constuire cet URL en en assemblant le début et la fin 
	urlCon2 = URI.encode(urlCon2)

	# On vérifie ensuite si la page du candidat est bel et bien en ligne, car certaines aboutissent à des culs-de-sac (404)

	u = URI.parse(urlCon2)
	yo = Typhoeus.get(u, followlocation: true) # On charge la page et on va sur une autre page si redirection il y a
	if yo.code == 200  # Si la page nous retourne le code 200 (ce qui veut dire que tout est beau; l'inverse de l'infâme 404), on poursuit
		candidatCon = Nokogiri::HTML(open(urlCon2, "User-Agent" => "Jean-Hugues Roy, UQAM (roy.jean-hugues@uqam.ca)"))
		candidat = {}
		candidat["Parti"] = "Parti conservateur"
		candidat["Code"] = "?"
		candidat["Circonscription"] = candidatCon.css("div.team-list-riding").text.strip
		candidat["Province"] = "?"
		candidat["Nom"] = candidatCon.css("h2").text.strip
		candidat["Twitter"] = candidatCon.css("a.w-inline-block.aside-meta-block")[1]["href"]
		puts candidat
		candidats.push candidat
	end
}

cons.close

tCon2 = Time.new
puts "On termine à #{tCon2}"

##################################################
# Extraction des candidats verts
##################################################

tVer1 = Time.new
puts "On commence à #{tVer1}"

codeCirc.each do |circ| # On passe tous les candidats verts à partir de la variable contenant tous les codes de circonscription créée plus haut
	urlVert = urlVerts + circ
	candidatVert = Nokogiri::HTML(open(urlVert, "User-Agent" => "Jean-Hugues Roy, UQAM (roy.jean-hugues@uqam.ca)"))
	candidat = {}
	candidat["Parti"] = "Parti vert"
	candidat["Code"] = circ
	candidat["Circonscription"] = candidatVert.css("h1.page-header").text.strip
	candidat["Province"] = "?"
	candidat["Nom"] = candidatVert.css("div.candidate-contact h2").text.strip
	if candidatVert.css("a[title='Twitter']") != nil
		candidatVert.css("a[title='Twitter']").map { |lien|
		candidat["Twitter"] = lien["href"]
	}
	else
		candidat["Twitter"] = ""
	end
	puts candidat
	candidats.push candidat
end

tVer2 = Time.new
puts "On termine à #{tVer2}"

##################################################
# Extraction des candidats du Bloc québécois
##################################################

tBloc1 = Time.new
puts "On commence à #{tBloc1}"

# Les candidatures du Bloc tiennent sur cinq pages

(1..5).each do |page|
	url = urlBloc + "page/#{page}"

	pageBloc = Nokogiri::HTML(open(url, "User-Agent" => "Jean-Hugues Roy, UQAM (roy.jean-hugues@uqam.ca)"))

	pageBloc.css("article").each do |candidatBloc|
		candidat = {}
		candidat["Parti"] = "Bloc québécois"
		candidat["Code"] = ""
		candidat["Circonscription"] = candidatBloc.css("h1").text.strip
		candidat["Province"] = "Québec"
		candidat["Nom"] = candidatBloc.css("h2").text.strip
		if candidatBloc.css("a.fb")[1] != nil
			candidat["Twitter"] = candidatBloc.css("a.fb")[1]["href"]
		end
		puts candidat
		candidats.push candidat
	end

end

tBloc2 = Time.new
puts "On termine à #{tBloc2}"

##################################################
# On affiche les temps de scraping de chaque parti en secondes
##################################################

tNPD = tNPD2 - tNPD1
puts "Scraper le NPD a pris #{tNPD.round(1)} secondes"
tLib = tLib2 - tLib1
puts "Scraper les Libéraux a pris #{tLib.round(1)} secondes"
tCon = tCon2 - tCon1
puts "Scraper les Conservateurs a pris #{tCon.round(1)} secondes"
tVer = tVer2 - tVer1
puts "Scraper les Verts a pris #{tVer.round(1)} secondes"
tBloc = tBloc2 - tBloc1
puts "Scraper le Bloc a pris #{tBloc.round(1)} secondes"

##################################################
# Et on met le tout dans un fichier CSV
##################################################

CSV.open("candidats.csv", "wb") do |csv|
	csv << candidats.first.keys
	candidats.each do |hash|
		csv << hash.values
	end
end
