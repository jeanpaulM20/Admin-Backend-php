<?php

class ExpressionNode extends ASTNode
{
	public static $paramCount = 0;
	public static $prefix = 'expression';
	protected $_operator;
	protected $_left;
	protected $_right; 
	
	public function getOperator() {
		return $this->_operator;
	}

	public function setOperator($operator) {
		$this->_operator = $operator;
	}

	public function getLeft() {
		return $this->_left;
	}

	public function setLeft($left) {
		$this->_left = $left;
	}

	public function getRight() {
		return $this->_right;
	}

	public function setRight($right) {
		$this->_right = $right;
	}

		
	public function toDbCriteria($mainModel, $criteria = null) {
		$expression = new CDbCriteria;
		$field = $this->_left->toDbCriteria($mainModel, $criteria);
		$value = $this->_right->toDbCriteria($mainModel, $criteria);
		$withParam = false;
		if ($value[0] == ':') {
			$withParam = true;
		} elseif (is_array($value)) {
			foreach ($value as $one) {
				if ($one[0] == ':') {
					$withParam = true;
				}
			}
		}
		if ($withParam) {
			switch (strtoupper($this->_operator)) {
				case '!=':
					$expression->addCondition($field . '<>' . $value);
					break;
				case '~':
					$expression->addCondition($field . ' LIKE ' . $value);
					break;
				case '!~':
					$expression->addCondition($field . ' NOT LIKE ' . $value);
				case 'IN':
					foreach ($value as $index => $val) {
						if ($val[0] != ':') {
							$param = ':' . self::$prefix . self::$paramCount++;
							$expression->params[$param] = $val;
							$value[$index] = $param;
						}
					}
					$expression->addCondition($field . ' IN (' . implode(',', $value) . ')');
					break;
				case 'NOT IN':
					foreach ($value as $index => $val) {
						if ($val[0] != ':') {
							$param = ':' . self::$prefix . self::$paramCount++;
							$expression->params[$param] = $val;
							$value[$index] = $param;
						}
					}
					$expression->addCondition($field . ' NOT IN (' . implode(',', $value) . ')');
					break;	
				default:
					$expression->addCondition($field . $this->_operator . $value);
			}
			return $expression;
		}
		switch (strtoupper($this->_operator)) {
			case '=':
			case '>':
			case '>=':
			case '<':
			case '<=':
				$expression->compare($field, $this->_operator . $value);
				break;
			case '!=':
				$expression->compare($field, '<>' . $value);
				break;
			case '~':
				$expression->compare($field, '=' . $value, true);
				break;
			case '!~':
				$expression->compare($field, '<>' . $value, true);
				break;
			case 'IN':
				$expression->addInCondition($field, $value);
				break;
			case 'NOT IN':
				$expression->addNotInCondition($field, $value);
				break;
			case 'IS':
				$expression->addCondition(array(
					$field . ' IS NULL',
					$field . ' = ""'
				), "OR");
				break;
			case 'IS NOT':
				$expression->addCondition(array(
					$field . ' IS NOT NULL',
					$field . ' <> ""'
				), "AND");
				break;
		}
		return $expression;
	}

	public function __toString() {
		return $this->_left . ' ' . $this->_operator . ' ' . $this->_right;
	}
}
?>
