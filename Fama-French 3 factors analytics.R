#Fama-French������ģ��Ӧ��
#���ذ�
install.packages("tidyverse")
install.packages("lubridate")
install.packages("readxl")
install.packages("highcharter")
install.packages("tidyquant")
install.packages("timetk")
install.packages("tibbletime")
install.packages("quantmod")
install.packages("PerformanceAnalytics")
install.packages("scales")
install.packages("broom")
install.packages("purrr")
install.packages("tidyr")
install.packages("magrittr")
install.packages('DBI')
install.packages('RMySQL')
library(DBI)
library(RMySQL)
library(tidyverse)
library(lubridate)
library(readxl)
library(highcharter)
library(tidyquant)
library(timetk)
library(tibbletime)
library(quantmod)
library(PerformanceAnalytics)
library(scales)
library(broom)
library(purrr)
library(tidyr)
library(magrittr)

#���ݵ���
data<-read.csv("C://Users//Administrator//Desktop//Fama-French.csv",header=T) 
colnames(data)[1] <- "date"
data$date <- as.character(data$date)
for (i in 1:length(data$date)){data$date[i]<- paste(substr(data$date[i],1,4),substr(data$date[i],5,6),"01",sep="-")}
data$date <- as.Date(data$date,format="%Y-%m-%d")
head(data,3)
#���ڴ���
data%>%
  select(date) %>%
  mutate(date = lubridate::rollback(date)) %>%
  head(1)
data %>%
  select(date) %>%
  mutate(date = lubridate::rollback(date + months(1))) %>%
  head(1)
#��������
data<-
  read.csv("C://Users//Administrator//Desktop//Fama-French.csv",header=T) %>%
  rename(date = X1) %>%
  mutate_at(vars(-date), as.numeric) %>%
  mutate(date =
           ymd(parse_date_time(date, "%Y%m"))) %>%
  mutate(date = rollback(date + months(1)))
head(data, 3)
#��Ͷ���������Ϊ8ֻ��Ʊ�����
#600000���ַ����У�Ȩ��20%
#600008���״��ɷݣ���Ȩ15%
#600011�����ܹ��ʣ���Ȩ15%
#600018���ϸۼ��ţ���Ȩ10%
#600022��ɽ����������Ȩ10%
#600030������֤ȯ����Ȩ10%
#600048�������ز�����Ȩ10%
#600054����ɽ���Σ���Ȩ10%

#��ȡ���ݿ�������

symbols<-c("600000","600008","600011","600018","600022","600030","600048","600054")
data1<-list()  #���������ݿ�
for (i in 1:8){ 
  mydb= dbConnect(MySQL(),user='ktruc002', password='35442fed', dbname='cn_stock_quote', host='172.19.3.250') 
  SQL_statement<-paste("SELECT  `day`,`close` 
FROM `cn_stock_quote`.`daily_adjusted_quote`
WHERE code=",symbols[i],"and day >='2008-12-31'<='2018-09-30'
ORDER BY 'day' DESC ")
  aa <- dbGetQuery(mydb,SQL_statement)
  colnames(aa)[2]<-paste("x",symbols[i],sep="",collaspe="")
  data1[[i]]=aa
}
stockdata<-data1%>%reduce(merge)
  prices<-xts(stockdata[,-1],order.by = as.Date(stockdata[,1]))
#8���ʲ��ı�����˳����symbols�е���ͬ
  w <- c(0.20,0.15,0.15,0.10,0.10,0.10,0.10,0.10)
  head(prices,3)
  
#ʹ��tidyverse������ת��Ϊ�¶Ȼر�
  asset_returns_dplyr_byhand <-
    prices %>%
    to.monthly(indexAt = "lastof", OHLC = FALSE) %>%
    #������ת��Ϊ����
    data.frame(date = index(.)) %>%
    #ɾ����������Ϊ����ת��Ϊ������
    remove_rownames() %>%
    gather(asset, prices, -date) %>%
    group_by(asset) %>%
    mutate(returns = (log(prices) - log(lag(prices)))) %>%
    select(-prices) %>%
    spread(asset, returns) 

  #��ȥNA��
  asset_returns_dplyr_byhand <-
    asset_returns_dplyr_byhand %>%
    na.omit()   
  #tidyverseҪ��ʹ��long��ʽ�������ʽ�����ݣ�����ÿ�����������Լ����У�������wide��ʽ
  #Ϊ��ʹ�ʲ��ر����࣬������Ҫһ����Ϊ��date�����С�һ����Ϊ��asset�����к�һ����Ϊ��returns������
  #asset_returns_long��3�У�ÿ���ж�Ӧһ������:���ڡ��ʲ����ر�
  asset_returns_long <-
    asset_returns_dplyr_byhand %>%
    gather(asset, returns, -date) %>%
    group_by(asset)
  #ʹ��tq_portfolio()��asset_returns_longת��ΪͶ����ϻر�
  portfolio_returns_tq_rebalanced_monthly <-
    asset_returns_long %>%
    tq_portfolio(assets_col = asset,
                 returns_col = returns,
                 weights = w,
                 col_rename = "returns",
                 rebalance_on = "months")
##�ص��ھ���
  ##left_joinʹ�����ܹ�����Щ���ݶ���ϲ���һ��Ȼ���κβ�ƥ��������������ǻ���FF����ת��Ϊʮ���Ƹ�ʽ��
  ##������һ���µ��г�ΪR_excess��ʹR_excess=returns - RF  
  ff_portfolio_returns <-
    portfolio_returns_tq_rebalanced_monthly %>%
    left_join(data, by ="date") %>%
    mutate(MKT_RF = RiskPremium,
           SMB =SMB,
           HML =HML,
           RF = Rf,
           R_excess = round(returns - Rf, 4)) %>%select(-returns, -Rf)
  ff_portfolio_returns <-
    ff_portfolio_returns%>%
    na.omit()   
##��ʼ��ģ����֮ǰ�����portfolio return,������,ͨ��lm������ʼ���beta�����⣬��������95����ϵ�����������䣬Ȼ����������
##ʹ������broom����tidy()�����������
  
  ff_dplyr_byhand <-
    ff_portfolio_returns %>%
    do(model =
         lm(R_excess ~ MKT_RF + SMB + HML,
            data = .)) %>%
    tidy(model, conf.int = T, conf.level = .95) %>%
    rename(beta = estimate)
  ##ת�����ݸ�ʽ������С��λ��������ʾ�ķֱ���beta��Ԥ��ֵ����׼�pvalue����������������
  ff_dplyr_byhand %>%
    mutate_if(is.numeric, funs(round(., 3))) %>%
    select(-statistic, -std.error)
  #ͨ��ggplot��FF���ӻ�
  ##������������,��filter�������˵� ����Intercept�������ؾ࣬ͨ��geom_errorbarչ�ֳ���������������ͼ��
  ##��ggplot2����ͼ�������ʽ���֣��������⣬��ע�����������ơ�ͨ��theme�������⡣
  ff_dplyr_byhand %>%
    mutate_if(is.numeric, funs(round(., 3))) %>%
    filter(term != "(Intercept)") %>%
    ggplot(aes(x = term,
               y = beta,
               shape = term,
               color = term)) +
    geom_point() +
    geom_errorbar(aes(ymin = conf.low,
                      ymax = conf.high)) +
    labs(title = "FF 3-Factor Coefficients",
         subtitle = "balanced portfolio",
         x = "",
         y = "coefficient",
         caption = "data source: Fama-French website") +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5),
          plot.subtitle = element_text(hjust = 0.5),
          plot.caption = element_text(hjust = 0))
  #�ع�����ʾ��HML���Ӻ�MKT_RF���ӹ�������Ҫ��������Դ����SMB���ӵ�betaֵ�����������ң������Ӷ��������Ĺ��ױȽ�С��
  #### ʹ��tidyverse��tibble-time����Fama-French
  #�������ʽFama-French�����̽����ģ���ڲ�ͬʱ����������
  #���¹����ض�����FF����ͨ������Ӧ��������ϣ��������ϵ��κζ�Ԫ���Իع�ģ�͡�
  #��������ʹ��tibbletime�е�rollify������������һ������ģ��
  # ѡ�� 24������Ϊ��������
  window <- 24
  # define a rolling ff model with tibbletime
  rolling_lm <-
    rollify(.f = function(R_excess, MKT_RF, SMB, HML) {
      lm(R_excess ~ MKT_RF + SMB + HML)
    }, window = window, unlist = FALSE)
  #####���ǽ��ʲ���ϵ������ʵ���rolling����
  rolling_ff_betas <-
    ff_portfolio_returns %>%
    mutate(rolling_ff =
             rolling_lm(R_excess,
                        MKT_RF,
                        SMB,
                        HML)) %>%
    slice(-1:-23) %>%
    select(date, rolling_ff)
  head(rolling_ff_betas, 3)
  
  #���ڣ���������һ����Ϊrolling_ff_betas�������ݿ����ǿ���ʹ��map��rolling_ff��tidy����������rolling_ff�У�
  ##Ȼ��ʹ��unnest�﷨��map����չ���ɶ��У�����CAPM�Ĺ����ǳ����ƣ�ֻ��FF�ж���Ա�����
  rolling_ff_betas <-
    ff_portfolio_returns %>%
    mutate(rolling_ff =
             rolling_lm(R_excess,MKT_RF,
                        SMB,
                        HML)) %>%
    mutate(tidied = map(rolling_ff,
                        tidy,
                        conf.int = T)) %>%
    unnest(tidied) %>%
    slice(-1:-23) %>%
    select(date, term, estimate, conf.low, conf.high) %>%
    filter(term != "(Intercept)") %>%
    rename(beta = estimate, factor = term) %>%
    group_by(factor)
  head(rolling_ff_betas, 3)
  ###���ڣ�����3�������е�ÿһ�����й�����beta���������䡣
  #���ǿ���Ӧ����ͬ�Ĵ����߼�����ȡģ�͵Ĺ���R2��Ψһ�����������ǳ�Ϊglance����������tidy������
  rolling_ff_rsquared <-
    ff_portfolio_returns %>%
    mutate(rolling_ff =
             rolling_lm(R_excess,
                        MKT_RF,
                        SMB,
                        HML)) %>%
    slice(-1:-23) %>%
    mutate(glanced = map(rolling_ff,
                         glance)) %>%
    unnest(glanced) %>%
    select(date, r.squared, adj.r.squared, p.value)
  head(rolling_ff_rsquared, 3)
  #�����Ѿ���ȡ�˹���beta�͹���ģ�ͽ�����������ǽ��п��ӻ���
  #### ʹ��ggplot��Fama-French���ӻ�
  #��������ʹ��ggplot�������ƹ�������betaͼ����ʹ���Ƕ�ÿ�����ӵĽ������������ʱ��仯����ֱ���ϵĸо�
  #����x��Ϊʱ���ᣬy�����Ϊbeta��������ͼ��24���µĹ�������beta���п��ӻ���
  #ͼ���������ǹ����ع�����betaֵ����ʾ��һЩ��Ȥ�����ơ������Ͽ���SMB��HML���ǻ����㸽������MKT�������ǻ���1���ҡ�
  ##�������ǵĴ������������beta����һ�¡�ͬʱ��HML����MB����etaֵ�����Ƚϴ󣬶�MKT_RF���ӵ�betaֵ�򲨶��Ƚ�С��
  rolling_ff_betas %>%
    ggplot(aes(x = date,
               y = beta,
               color = factor)) +
    geom_line() +
    labs(title= "24-Month Rolling FF Factor Betas") +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5),
          axis.text.x = element_text(angle = 90))
  #���ڣ����ǶԹ���R2���п��ӻ�
  #��������ʹ��timetk�е�tk_xts����������R2ת��Ϊxts����
  rolling_ff_rsquared_xts <-
    rolling_ff_rsquared %>%
    tk_xts(date_var = date, silent = TRUE)
  highchart(type = "stock") %>%
    hc_add_series(rolling_ff_rsquared_xts$r.squared,
                  color = "cornflowerblue",
                  name = "r-squared") %>%hc_title(text = "Rolling FF 3-Factor R-Squared") %>%
    hc_add_theme(hc_theme_flat()) %>%
    hc_navigator(enabled = FALSE) %>%
    hc_scrollbar(enabled = FALSE) %>%
    hc_exporting(enabled = TRUE)
  #��Ȼ���ͼ�Ƚϲ��ȶ�����R2��δ�����뿪����0.9��0.95������䡣���ǿ��Ե���y�����С�����ֵ��
  highchart(type = "stock") %>%
    hc_add_series(rolling_ff_rsquared_xts$r.squared,
                  color = "cornflowerblue",name = "r-squared") %>%
    hc_title(text = "Rolling FF 3-Factor R-Squared") %>%
    hc_yAxis( max = 2, min = 0) %>%
    hc_add_theme(hc_theme_flat()) %>%
    hc_navigator(enabled = FALSE) %>%
    hc_scrollbar(enabled = FALSE) %>%
    hc_exporting(enabled = TRUE)
  
  #����ͼ��ʾ����y�᷶Χ����ʱ�����ǵ�R2��Ͷ����ϵ���Ч���ڲ���������С�˺ܶࡣ����������2017��֮ǰ��
 # R-Squared��ֵ������0.7���ϣ�˵��������ģ�Ͷ���������ʵĽ������Ⱥܺã����ǣ�2018�꿪ʼ��
  #R-Squared��ֵ�����½�����ͽ���0.3���£�˵�����ʱ��������ģ�Ͷ���ϵĽ������ȱȽϲ
  
  
  
  
  
  
  
  
  
  
  

