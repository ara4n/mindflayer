library(jpeg)
library(grid)
library(maps)
library(geosphere)
library(grid)
library(magrittr)
library(dplyr)
library(ggplot2)

# Load dataset from github (Surfer project)
data <- read.table("connections.tsv", header=T, sep='\t')

# print(data)

# Download NASA night lights image
# download.file("https://www.nasa.gov/specials/blackmarble/2016/globalmaps/BlackMarble_2016_01deg.jpg",
#               destfile = "IMG/BlackMarble_2016_01deg.jpg", mode = "wb")

# Load picture and render
#earth <- readJPEG("IMG/BlackMarble_2016_01deg.jpg", native = TRUE)
earth <- readJPEG("IMG/world.topo.bathy.200408.3x5400x2700.jpg", native = TRUE)
earth <- rasterGrob(earth, interpolate = TRUE)

# Count how many times we have each unique connexion + order by importance
summary=data %>%
  dplyr::count(lat_a,long_a, lat_b,long_b, weight) %>%
  arrange(n)

# print(summary)

# A function that makes a dataframe per connection (we will use these connections to plot each lines)
data_for_connection=function( dep_lon, dep_lat, arr_lon, arr_lat, group ) {
  inter <- gcIntermediate(c(dep_lon, dep_lat), c(arr_lon, arr_lat), n=50, addStartEnd=TRUE, breakAtDateLine=F)
  inter=data.frame(inter)
  inter$group=NA
  diff_of_lon=abs(dep_lon) + abs(arr_lon)
  if(diff_of_lon > 180){
    inter$group[ which(inter$lon>=0)]=paste(group, "A",sep="")
    inter$group[ which(inter$lon<0)]=paste(group, "B",sep="")
  }else{
    inter$group=group
  }
  return(inter)
}

# Création d'un dataframe complet avec les points de toutes les lignes à faire.
data_ready_plot=data.frame()
for(i in c(1:nrow(summary))){
  tmp=data_for_connection(summary$long_a[i], summary$lat_a[i], summary$long_b[i], summary$lat_b[i], i)
  tmp$weight=summary$weight[i]
  tmp$n=summary$n[i]
  # print(tmp)
  data_ready_plot=rbind(data_ready_plot, tmp)
}
#data_ready_plot$homecontinent=factor(data_ready_plot$homecontinent, levels=c("Asia","Europe","Australia","Africa","North America","South America","Antarctica"))

# Plot
p <- ggplot() +
  annotation_custom(earth, xmin = -180, xmax = 180, ymin = -90, ymax = 90) +
  geom_line(data=data_ready_plot, aes(x=lon, y=lat, group=group, colour=weight, alpha=weight), size=0.6) +
  scale_color_distiller(palette="YlOrRd") + # Options are YlOrRd or PuBuGn 
  theme_void() +
  theme(
        legend.position="none",
        panel.background = element_rect(fill = "black", colour = "black"),
        panel.spacing=unit(c(0,0,0,0), "null"),
        plot.margin=grid::unit(c(0,0,0,0), "cm"),
  ) +
  # ggplot2::annotate("text", x = -150, y = -45, hjust = 0, size = 11, label = paste("Top 100 Matrix homeservers"), color = "white") +
  # ggplot2::annotate("text", x = -150, y = -51, hjust = 0, size = 8, label = paste("Line brightness reflects DAU"), color = "white", alpha = 0.5) +
  #ggplot2::annotate("text", x = 160, y = -51, hjust = 1, size = 7, label = paste("Cacedédi Air-Guimzu 2018"), color = "white", alpha = 0.5) +
  xlim(-180,180) +
  ylim(-60,80) +
  scale_x_continuous(expand = c(0.006, 0.006)) +
  coord_equal()

# Save at PNG
ggsave("IMG/matrix.png", width = 36, height = 15.22, units = "in", dpi = 90)
