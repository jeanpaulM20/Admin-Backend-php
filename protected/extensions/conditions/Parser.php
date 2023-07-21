<?php

class Parser
{
	const STATE_WAITING_EXPRESSION_START = 0;
	const STATE_WAITING_OPERATOR = 1;
	const STATE_WAITING_LOGICAL = 2;
	const STATE_WAITING_EXPRESSION_END = 3;
	const STATE_WAITING_LIST_START = 4;
	const STATE_WAITING_LIST_ITEM = 5;
	const STATE_WAITING_COMMA = 6;

	protected static $_lastNode;
	protected static $_bracketsDepth = 0;
	protected static $_bracketsNodes = array();

	public static function parse($mainModel, $input) 
	{
		$tokens = Tokenizer::run($input);
	
		$state = self::STATE_WAITING_EXPRESSION_START;
		
		$left = null;
		$operator = null;
		$list = null;
		
		foreach ($tokens as $token) {
			switch ($state) {
				case self::STATE_WAITING_EXPRESSION_START:
					if ($token == '(') {
						self::$_bracketsDepth++;
						continue;
					}
					if (Tokenizer::checkIsString($token)) {
						throw new ParserException("Waiting for field name, found string " . $token);
					}
					if (Tokenizer::checkIsOperator($token)) {
						throw new ParserException("Waiting for field name, found operator " . $token);
					}
					if (Tokenizer::checkIsLogic($token)) {
						throw new ParserException("Waiting for field name, found " . $token);
					}
					$left = $token;
					$state = self::STATE_WAITING_OPERATOR;
					break;
				case self::STATE_WAITING_EXPRESSION_END:
					if ($token == ')') {
						throw new ParserException("Unexpected closing bracket, expecting second expression part");
					}
					if (strtoupper($token) == 'NOT') {
						$operator .= ' ' . $token;
						continue;
					} elseif (strtoupper($operator) == 'NOT' && strtoupper($token) == 'IN') {
						$operator .= ' ' . $token;
						$state = self::STATE_WAITING_LIST_START;
						continue;
					}
					if ((strtoupper($operator) == 'IS' || strtoupper($operator) == 'IS NOT') && strtoupper($token) != 'EMPTY') {
						throw new ParserException("Expected EMPTY keyword, found " . $token);
					}
					if (Tokenizer::checkIsOperator($token)) {
						throw new ParserException("Waiting for second expression part, found operator " . $token);
					}
					if (Tokenizer::checkIsLogic($token)) {
						throw new ParserException("Waiting for second expression part, found " . $token);
					}
					$node = self::createNode('expression');
					$node->setLeft(new FieldNode($left));
					$node->setOperator($operator);
					$node->setRight(new ValueNode($token));
					$left = null;
					$operator = null;
					$state = self::STATE_WAITING_LOGICAL;
					break;
				case self::STATE_WAITING_OPERATOR:
					if ($token == ')') {
						throw new ParserException("Unexpected closing bracket, expecting operator");
					}
					if (!Tokenizer::checkIsOperator($token)) {
						throw new ParserException("Waiting operator, found " . $token);
					}
					$operator = $token;
					if (strtoupper($operator) == 'IN') {
						$state = self::STATE_WAITING_LIST_START;
						continue;
					}
					
					$state = self::STATE_WAITING_EXPRESSION_END;
					break;
				case self::STATE_WAITING_LOGICAL:
					if ($token == ')') {
						if (self::$_bracketsDepth) {
							if (self::$_bracketsDepth > 1) {
								self::$_bracketsNodes[self::$_bracketsDepth-1]->addLeaf(new GroupingNode(self::$_bracketsNodes[self::$_bracketsDepth]));
							} else {
								if (self::$_lastNode) {
									self::$_lastNode->addLeaf(new GroupingNode(self::$_bracketsNodes[self::$_bracketsDepth]));
								} else {
									self::$_lastNode = new GroupingNode(self::$_bracketsNodes[self::$_bracketsDepth]);
								}
							}
							unset(self::$_bracketsNodes[self::$_bracketsDepth]);
							self::$_bracketsDepth--;
							continue;
						} else {
							throw new ParserException("Unexpected closing bracket, logical operator");
						}
					}
					if (!Tokenizer::checkIsLogic($token)) {
						throw new ParserException("Waiting operator, found " . $token);
					}
					$node = self::createNode(strtoupper($token));
					$state = self::STATE_WAITING_EXPRESSION_START;
					break;
				case self::STATE_WAITING_LIST_START:
					if ($token != '(') {
						throw new ParserException("Expecting items list, bu found " . $token);
					}
					$state = self::STATE_WAITING_LIST_ITEM;
					break;
				case self::STATE_WAITING_LIST_ITEM:
					if ($token == ')') {
						throw new ParserException("Unexpected closing bracket, expecting list item");
					}
					if (Tokenizer::checkIsOperator($token)) {
						throw new ParserException("Waiting for list item, found operator " . $token);
					}
					if (Tokenizer::checkIsLogic($token)) {
						throw new ParserException("Waiting for list item, found " . $token);
					}
					if ($list == null) {
						$list = new ListNode();
					}
					$list->addItem(new ValueNode($token));
					$state = self::STATE_WAITING_COMMA;
					break;
				case self::STATE_WAITING_COMMA:
					if ($token == ')') {
						$node = self::createNode('expression');
						$node->setLeft(new FieldNode($left));
						$node->setOperator($operator);
						$node->setRight($list);
						$left = null;
						$operator = null;
						$list = null;
						$state = self::STATE_WAITING_LOGICAL;
						continue;
					}
					if ($token != ',') {
						throw new ParserException('Expected comma but found ' . $token);
					}
					$state = self::STATE_WAITING_LIST_ITEM;
					break;
			}
		}
		
		switch ($state) {
			case self::STATE_WAITING_EXPRESSION_END:
				throw new ParserException("Unexpected end, expecting second expression part");
			case self::STATE_WAITING_OPERATOR:
				throw new ParserException("Unexpected end, expecting operator");
		}
		
		if (self::$_bracketsDepth > 0) {
			throw new ParserException("Brackets not closed");
		}
		$criteria = new CDbCriteria;
		if (self::$_lastNode) {
			$rootCriteria = self::$_lastNode->toDbCriteria($mainModel, $criteria);
			$rootCriteria->mergeWith($criteria);
			return $rootCriteria;
		} else {
			return $criteria;
		}
	}
	
	public static function createNode($type) {
		$node = null;
		switch ($type) {
			case 'expression':
				$node = new ExpressionNode;
				break;
			case 'OR':
				$node = new OrNode;
				break;
			case 'AND':
				$node = new AndNode;
				break;
		}
		if (self::$_bracketsDepth > 0) {
			if (!isset(self::$_bracketsNodes[self::$_bracketsDepth])) {
				self::$_bracketsNodes[self::$_bracketsDepth] = $node;
			} else {
				if ($node instanceof AndNode || $node instanceof OrNode) { 
					$node->addLeaf(self::$_bracketsNodes[self::$_bracketsDepth]);
					self::$_bracketsNodes[self::$_bracketsDepth] = $node;
				} else {
					self::$_bracketsNodes[self::$_bracketsDepth]->addLeaf($node);
				}
			}
		} elseif (self::$_lastNode) {
			if ($node instanceof AndNode || $node instanceof OrNode) { 
				$node->addLeaf(self::$_lastNode);
				self::$_lastNode = $node;
			} else {
				self::$_lastNode->addLeaf($node);
			}
		} else {
			self::$_lastNode = $node;
		}
		return $node;
	}
}
?>
