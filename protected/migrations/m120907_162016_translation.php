<?php
class m120907_162016_translation extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_translation')) {
        	$this->createTable('tbl_translation', array(
				'id' => 'pk',
				'label' => 'string NULL',
				'value' => 'string NULL',
				'language_rel' => 'integer NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');

        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_translation')) {
        	$this->dropTable('tbl_translation');
        }
    }
}