<?php
class m120907_162016_content extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_content')) {
        	$this->createTable('tbl_content', array(
				'id' => 'pk',
				'name' => 'string NULL',
				'group' => 'string NULL',
				'type' => 'string NULL',
				'preview' => 'string NULL',
				'teaser' => 'text NULL',
				'file' => 'string NULL',
				'startdate' => 'date NULL',
				'enddate' => 'date NULL',
				'archive' => 'boolean NULL',
				'published' => 'boolean NULL',
				'language_rel' => 'integer NULL',
				'trainer_id' => 'integer NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('trainer_id', 'tbl_content', 'trainer_id', false);				

			
				if (!$this->getDbConnection()->getSchema()->getTable('tbl_content_client')) {
	$this->createTable('tbl_content_client', array(
		'content_id' => 'integer NOT NULL',
		'client_id' => 'integer NOT NULL',
		'PRIMARY KEY (content_id, client_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_content')) {
        	$this->dropTable('tbl_content');
        }
    }
}