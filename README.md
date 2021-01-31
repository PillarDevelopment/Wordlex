# WordLex
[Official webSite](https://www.wordlex.finance/)


###SHASTA

[WDX Token](https://shasta.tronscan.org)

[sEE mORE](https://github.com/zyumingfit/TRC20-Contract-Template)


[PRICE Controller](https://shasta.tronscan.org)


```getCirrentUSDRate()``` - Возвращает текущую цену к доллару в sun - сколько sun стоит 1 USD;


```PriceProvider``` - возвращает текущуй адрес поставщика данных о цене;


```setPriceProvoder(address)``` - изменяет адрес поставщика цены - только владелец контракта;


```updateUSDRate(uint256)``` - изменить цену - только поставщик цены;


[WDX Status](https://shasta.tronscan.org)


```getStatusPrice(id)``` - возвращает цену статуса в sun;


```getStatusLines(id)``` - возвращает количество линий для статуса;


```getStatusLimit(id)``` - возвращает лимит вывода для статуса;


```getStatusName(id)```- возвращает название статуса в string;


```getADdressStatus(addresss)``` - вовзаращает id статуса для адреса;


```getStatusUSDPrice(id)``` - возвращает цену статуса в USD;


```admin``` - возвращает адрес админа;


```controller``` - возвращает  адрес поставщика цены;


```totalUsers``` - вовзаращет количество покупателей статусов;


```totalWithdraw``` - возвращает общую сумму выводов;


```owner``` - возвращает адрес владельца контракта;


```users``` - возвращает данные по покупателю статуса;


```buyStatus(id, upliner)``` - покупка статуса;


```upgradeStatus(id)``` - улучшение статуса;


```setAddressAdmin(address)``` - изменить адрес admin;


```addStatus(price, limit, lines, name)``` - добавить новый тип статуса;


```withdraw()``` - вывести средства за реферальную программу;


```setRefBonusesPercentage(line, percentage)``` - изменить значения в линии;


[WDX Stacking](https://shasta.tronscan.org)

```deposit(address _upline, uint256 _amount)``` - внесение депозита

```withdraw(uint256 )``` - вывод средств

```setMinimumDailyPercent(uint256)``` - изменить минимальный процент

```setRefBonusesPercentage(uint256, uint8)``` - изменить проценты в реферальной програме - только Owner

```maxDailyPayoutOf(address)``` - получить доступный вывод для статуса адреса

```payoutOf(address, uint256) ``` - получить сумму вывода

```getDailyPercent(address)``` - получить максимальный дневной процент для адреса

```getTimeBonus(uint256)``` - получить процент по времени депозита

```getDepositHoldBonus(uint256)``` - получить процент по сумме депозита

```userInfo(address)``` - информация о юзере

```generateCompoundInterest(address, uint256)``` - получить величину сложного процента для пользователя


[WDX AutoProgram](https://shasta.tronscan.org/#/contract/TXomuyS5W8pZpWu58LmPP9hHvPa1tni8kh/code)

 ```users(address)``` - ВОзвращает данные юзера по адресу

 ```ids(uint)``` - возвращает id юзера по адресу

```registration(address, uint256, address) ``` - регистрация юзеро - только Owner

```acceptPaidForCar(address)``` - Вывод средств за машины - только Owner

```setUserCarPrice(address, uint256) ``` - Изменить цену авто - только Owner
         
```setRefBonusesPercentage(uint256, uint8)``` - изменить проценты в реферальной програме - только Owner
         
```buyCar(uint256)```  - купить авто

```checkThreeComrades(address, address, address)``` - 'Три друга'

```withdraw()``` - вывод накопленных бонусов
        
```checkActiveStatus()``` - получить активный статус если выполнены условия
         
```liquidateInactiveAccount(address)``` - ликвидировать награду неактивного аккаунта в соостветствии с уловиМи

```getsBuyersIn1Line(address _addr)``` - получить количество покупателей из первой линии

```getAddressFirstLine(address _addr)```   - получить id юзеров из первой линии 

```getTotalUsers() ``` - получить общее количество пользователей 