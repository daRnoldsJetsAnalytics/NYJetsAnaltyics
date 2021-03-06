##########################################################
#  
#    Bar Chart: Passes At/Behind the LOS, AY Analysis
#    @NYJetsAnalytics
#    Originally Created: 10/8/2019
#
##########################################################

#load packages 
library(nflscrapR)
library(dplyr)
library(na.tools)
library(magrittr)
library(ggplot2)
library(ggimage)
library(tidyverse)
library(scales)
library(extrafont)
library(extrafontdb)
library(stats)
library(ggrepel)
library(ggthemes)

#read in play-by-play data for the 2019 regular season (hosted on Ryan Yurko's github)
#this method is faster than the fuction scrape_season_play_by_play()
season_2019 <- read_csv("https://raw.githubusercontent.com/ryurko/nflscrapR-data/master/play_by_play_data/regular_season/reg_pbp_2019.csv")

#read in team logos, colors 
logos <- read_csv("https://raw.githubusercontent.com/NYJetsAnalytics/NYJetsAnalytics/master/data_sets/logosdf.csv")
team_colors <- read_csv("https://raw.githubusercontent.com/NYJetsAnalytics/NYJetsAnalytics/master/data_sets/teamcolorsdf.csv")

# Pull out Jets' primary color (used in title color and border color)
nyj_color <- team_colors %>%
  filter(team == "NYJ") %>%
  pull(color)

## BEGIN BEN BALDWIN MUTATIONS ##
#filter by plays where play type is "no play", "pass", or "rush". remove plays where epa is NA
pbp_2019 <- season_2019 %>%
  filter(!is.na(epa), play_type=="no_play" | play_type=="pass" | play_type=="run")

#account for plays that are nullified by penalties add new variables - pass, rush, success.
pbp_2019 <- pbp_2019 %>%
  mutate(
    pass = if_else(str_detect(desc, "(pass)|(sacked)|(scramble)"), 1, 0),
    rush = if_else(str_detect(desc, "(left end)|(left tackle)|(left guard)|(up the middle)|(right guard)|(right tackle)|(right end)") & pass == 0, 1, 0),
    success = ifelse(epa>0, 1 , 0)
  )

#text scrape play descriptions to get player names
pbp_players <- pbp_2019 %>% 
  mutate(
    passer_player_name = ifelse(play_type == "no_play" & pass == 1, 
                                str_extract(desc, "(?<=\\s)[A-Z][a-z]*\\.\\s?[A-Z][A-z]+(\\s(I{2,3})|(IV))?(?=\\s((pass)|(sack)|(scramble)))"),
                                passer_player_name),
    receiver_player_name = ifelse(play_type == "no_play" & str_detect(desc, "pass"), 
                                  str_extract(desc, 
                                              "(?<=to\\s)[A-Z][a-z]*\\.\\s?[A-Z][A-z]+(\\s(I{2,3})|(IV))?"),
                                  receiver_player_name),
    rusher_player_name = ifelse(play_type == "no_play" & rush == 1, 
                                str_extract(desc, "(?<=\\s)[A-Z][a-z]*\\.\\s?[A-Z][A-z]+(\\s(I{2,3})|(IV))?(?=\\s((left end)|(left tackle)|(left guard)|		(up the middle)|(right guard)|(right tackle)|(right end)))"),
                                rusher_player_name)
  )
## END OF BEN BALDWIN MUTATIONS ##

#summarize total dropbacks and pass attempts
total <- pbp_players %>%
  filter(!is.na(posteam)) %>% 
  group_by(posteam)%>%
  summarise(
    n_dropbacks = sum(pass))%>%
  mutate(
    #create variable "url_coord" to tell the plot where to place the team logo on the bar chart
    url_coord = n_dropbacks
  )%>%
  arrange(posteam)

#create data frame, neg_ays, for negative (and 0) air yards pass attempts from cleaned play by play data
neg_ays <- pbp_players %>% filter(!is.na(air_yards), air_yards <=0)

#summarize neg air yards dropbacks and pass attempts
neg <- neg_ays %>%
  group_by(posteam)%>%
  summarise(
    n_dropbacks = sum(pass))%>%
  arrange(posteam)

#create new data frame delta to get the number of pass attempts for positive air yards, will be used in the plot later
delta <- total[,2]-neg[,2]

#create new data frame, clean_total by cbinding total and delta 
clean_total <- cbind(total,delta)

#remove redundant column
clean_total <- clean_total[,-2]

#join logos and colors by team
clean_total <- clean_total %>% left_join(logos, by=c("posteam"="team")) %>% left_join(team_colors, by=c("posteam"="team"))

#rename columns, posteam, url_coord, pos_ay, url(link to logos)
names(clean_total) <- c("posteam", "url_coord", "pos_ay", "url", "color", "color2", "color3", "color4")

#create data frame df with variables perc (calculate % of neg and 0 air yard passes) and mid_point (coordinate used in the plot)
df <- clean_total %>%
  group_by(posteam)%>%
  mutate(
    perc = ifelse(!is.na(url_coord),round(abs(pos_ay/url_coord*100-100),2),NA),
    mid_point = mean(c(url_coord, pos_ay))
  )

#plot, sorted by smallest percentage of passes behind the LOS to the largest
df %>% 
  ggplot(aes(x = reorder(posteam, -perc))) +
  geom_bar(aes(y=url_coord,color=df$posteam,fill=df$posteam), position = "identity",stat="identity", alpha=.2,show.legend=FALSE, width = .45) +
  geom_bar(aes(y=pos_ay,color=df$posteam,fill=df$posteam), position = "identity",stat="identity", show.legend=FALSE, width = .45) +
  coord_flip()+
  scale_y_continuous(breaks=seq(0,1000,50), expand = c(.01,0))+
  scale_color_manual(values=c(df$color))+
  scale_fill_manual(values=c(df$color))+
  geom_text(aes(x=posteam, y=mid_point, label = paste0(perc," %"), fontface="bold", size=8), show.legend=FALSE)+ 
  geom_image(aes(x=posteam, y=url_coord, image = url), size = 0.025, by = "width", asp =1.8) +
  labs(title = "Pass Attempts by Team in 2019 (Regular Season)",
       subtitle = "Quantifying Targets at or Behind the LOS",
       caption = "Plot by @NYJAnalytics, Data from @nflscrapR")+
  ggthemes::theme_fivethirtyeight()+
  theme(panel.grid.major.y = element_blank(),
        plot.title=element_text(color= nyj_color),  # title
        plot.caption=element_text(color = nyj_color, 
                                  face ="bold"),
        axis.text.y = element_blank()
  )

#export high quality png file to your machine
ggsave("Targets Behind LOS 2019.png", path="%local path here%",height = 7.5, width = 16,units = "in", device = "png", dpi = 500)
