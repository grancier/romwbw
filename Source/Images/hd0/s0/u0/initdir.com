�Z3ENV  INITDIR  ��s�1��S� 2�!� F(:#~�/�o� (��	(�2��A8�Q8F�c1�Q�S�S�l�Y�K�)�P�2�!�yw#��S�l�A8�Q8n�S�2�:� ��S:�_� �X:��A�_�7  � !^�w w#�^� <��X�O͇|��c^#V�S�	 ^#V���!��V�^�S��:��:��S�  :� ����S����v�� ���B	� �:_	�! ��<!��[�  ~��(�!(}� o0$z� ��!��!�  �x(�*���R��<!�6!#��!Y ��!Y ���6 #6 #��6 :� 3�S!�  �S��[�~��(+�!('�y������D��_ �~ � �!��~�����  �z� �y�()� �!��~�y������D��o& � ��R(6�#���*��[���R(!� `6�#��!�  ����� ͥ�D��S��<��2�����!  �V�^ >��R?8���=(�����f�n	DM͍��[�ͫDM͓��͙͟� ����su���!  �K��V�^ >��R?8���=(�����f�n	DM͍��[�ͫDM͓� ͙  ͥ�(� �K��C�����:�O � ͇�� ��)��S:���Q�{���	� �S�S�l�Y��)�� �(��a��{��_� ~#��� $� � �! �$ �' �-  ��* 	���

Illegal drive name$
Directory already initialized$
Not enough directory space on disk$
INITDIR  Ver 1.2  12 Apr 93

   Initializing a Disk for P2DOS Date/Time Stamps which already 
   contains files marked with DateStamper Stamps may invalidate
   the existing DateStamper Times and Dates!
$
     Confirm Initialize Drive $: $(Y/[N]) : $

Initialize which Disk for P2DOS Date/Time Stamps? : $

Initialize another Disk? $ $
Directory read error$
Directory write error$
Usage: Prepare disk for CP/M-3 (P2DOS) style date/time stamping

Syntax:
	INITDIR		- Enter Interactive Mode
	INITDIR d:	- Initialize drive "d"
	INITDIR //	- Display this message

Note: ZCNFG may be used to configure a flag to suppress
      drive confirmation prompt and status messages
$
$
--> DateStamper !!!TIME&.DAT File Found <--
	Proceed anyway $
...Reading Directory Entries...$
...Writing Initialized Directory...$      !!!TIME&DAT                                                                                                                                                      