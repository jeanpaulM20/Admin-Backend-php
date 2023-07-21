<?php

class Tokenizer
{
	protected static $_specialChars = array(
		'=',
		'!',
		'<',
		'>',
		'~',
		'"',
		' ',
		'(',
		')',
		'\\',
		',',
	);
	protected static $_systemTokens = array(
		'!=',
		'>=',
		'<=',
		'!~',
	);
	
	public static $operators = array(
		'=',
		'>',
		'>=',
		'<',
		'<=',
		'!=',
		'~',
		'!~',
		'IN',
		'IS',
		'NOT',
		//'EMPTY',
	);
	
	public static $logic = array(
		'AND',
		'OR'
	);

	public static function run($input) {
		$symbols = preg_split('/(?<!^)(?!$)/u', $input);
		$tokens = array();
		$curToken = '';
		$len = count($symbols);
		$inString = false;
		for ($i = 0; $i < $len; ++$i) {
			$symbol = $symbols[$i];
			if (in_array($symbol, self::$_specialChars)) {
				if (in_array($symbol . $symbols[$i+1], self::$_systemTokens)) {
					if ($curToken != '') {
						$tokens[] = $curToken;
						$curToken = '';
					}
					$tokens[] = $symbol . $symbols[$i+1];
					$i++;
				} else {
					if ($inString) {
						$curToken .= $symbol;
						if ($symbol == '\\' && $symbols[$i + 1] == '"') {
							$curToken .= $symbols[$i+1];
							$i++;
						} elseif ($symbol == '"') {
							$tokens[] = $curToken;
							$curToken = '';
							$inString = false;
						}
					} elseif ($symbol == '"') {
						$curToken .= $symbol;
						$inString = true;
					} else {
						if ($curToken != '') {
							$tokens[] = $curToken;
						}
						if ($symbol != ' ') {
							$tokens[] = $symbol;
						}
						$curToken = '';
					}
				}
			} else {
				$curToken .= $symbol;
			}
		}
		if ($curToken != '') {
			$tokens[] = $curToken;
		}
		
		return $tokens;
	}
	
	public static function checkIsString($token) {
		if ($token[0] == '"' && $token[strlen($token)-1] = '"') {
			return true;
		}
		if ($token[0] == '"') {
			throw new ParserException('Missing closing quote');
		}
		
		return false;
	}
	
	public static function checkIsOperator($token) {
		return in_array(strtoupper($token), self::$operators);
	}
	
	public static function checkIsLogic($token) {
		return in_array(strtoupper($token), self::$logic);
	}
}
?>
