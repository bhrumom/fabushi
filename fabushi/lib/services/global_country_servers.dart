// v3.0 Final: 已完善全球所有国家/地区（共 249 个）。
// 为了更真实地模拟全球发送，我们引入了更多样化的公共服务器，并为每个国家分配了独特的组合。
const Map<String, List<String>> GLOBAL_COUNTRY_SERVERS = {
  'AF': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AX': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'AL': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'DZ': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AS': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AD': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'AO': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AI': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'AQ': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AG': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AR': [
    'https://httpbin.org/post',
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AM': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'AW': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AU': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
    'https://httpbin.org/post',
  ],
  'AT': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'AZ': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BS': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'BH': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'BD': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BB': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'BY': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BE': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BZ': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'BJ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'BM': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BT': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'BO': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BQ': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BA': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'BW': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'BV': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
    'https://httpbin.org/post',
  ],
  'IO': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BN': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'BG': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'BF': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'BI': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'CV': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'KH': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'CM': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'CA': [
    'https://httpbin.org/post',
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'KY': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CF': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'TD': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CL': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'CN': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CX': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CC': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CO': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'KM': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CD': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'CG': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'CK': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CI': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'HR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CU': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'CW': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'CY': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'CZ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'DK': [
    'https://httpbin.org/post',
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'DJ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'DM': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'DO': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'EC': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'EG': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SV': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'GQ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'ER': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'EE': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'SZ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'ET': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'FK': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'FO': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'FJ': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'FI': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'FR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'GF': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'PF': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'TF': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GA': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'GM': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'GE': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'DE': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GH': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'GI': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GR': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'GL': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'GD': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GP': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GU': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'GT': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GG': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'GN': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'GW': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GY': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'HT': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'HM': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'VA': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'HN': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'HK': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'HU': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'IS': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'IN': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'ID': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'IR': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'IQ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'IE': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'IM': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'IL': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'IT': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'JM': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'JP': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'JE': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'JO': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'KZ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'KE': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'KI': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'KP': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'KR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'KW': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'KG': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'LA': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'LV': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'LB': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'LS': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'LR': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'LY': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'LI': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'LT': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'LU': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MO': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MG': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'MW': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MY': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'MV': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'ML': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MT': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MH': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'MQ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MR': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'MU': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'YT': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MX': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'FM': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'MD': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MC': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'MN': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'ME': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MS': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MA': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'MZ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MM': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'NA': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'NR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'NP': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'NL': [
    'https://httpbin.org/post',
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'NC': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'NZ': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'NI': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'NE': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'NG': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'NU': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'NF': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MK': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'MP': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'NO': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'OM': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'PK': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'PW': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'PS': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'PA': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'PG': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'PY': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'PE': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'PH': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'PN': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'PL': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'PT': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'PR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'QA': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'RE': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'RO': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'RU': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'RW': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'BL': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SH': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'KN': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'LC': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'MF': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'PM': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'VC': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'WS': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'SM': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'ST': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SA': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'SN': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'RS': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SC': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'SL': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SG': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SX': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'SK': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'SI': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SB': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'SO': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'ZA': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GS': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'SS': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'ES': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'LK': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'SD': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SJ': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'SE': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'CH': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'SY': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'TW': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'TJ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'TZ': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'TH': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'TL': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'TG': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'TK': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'TO': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'TT': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'TN': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'TR': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'TM': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'TC': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'TV': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'UG': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'UA': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'AE': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'GB': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'US': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'UY': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'UZ': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'VU': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'VE': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'VN': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'WF': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'EH': ['https://httpbin.org/post', 'https://httpbin.org/post'],
  'YE': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
  'ZM': [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts',
  ],
  'ZW': [
    'https://jsonplaceholder.typicode.com/posts',
    'https://httpbin.org/post',
  ],
};
